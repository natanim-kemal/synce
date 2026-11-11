import { Stack, StackProps, CfnOutput, Duration, RemovalPolicy, Fn } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as route53 from 'aws-cdk-lib/aws-route53';
import * as cdk from 'aws-cdk-lib';

// SSH is restricted to the operator's current IP; update and redeploy if it changes.
const SSH_ALLOWED_CIDR = '196.189.18.32/32';

export class SynceStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'Vpc', {
      maxAzs: 2,
      natGateways: 0,
      subnetConfiguration: [
        { name: 'public', subnetType: ec2.SubnetType.PUBLIC, cidrMask: 24 },
        { name: 'db', subnetType: ec2.SubnetType.PRIVATE_ISOLATED, cidrMask: 24 },
      ],
    });

    const appSg = new ec2.SecurityGroup(this, 'AppSg', {
      vpc,
      description: 'synce app host',
      allowAllOutbound: true,
    });
    appSg.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(80), 'HTTP (certbot + redirect)');
    appSg.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.tcp(443), 'HTTPS');
    appSg.addIngressRule(ec2.Peer.ipv4(SSH_ALLOWED_CIDR), ec2.Port.tcp(22), 'SSH from operator');

    const dbSg = new ec2.SecurityGroup(this, 'DbSg', {
      vpc,
      description: 'synce postgres',
      allowAllOutbound: false,
    });
    dbSg.addIngressRule(appSg, ec2.Port.tcp(5432));

    const role = new iam.Role(this, 'AppRole', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
    });
    role.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
    );
    role.addToPolicy(
      new iam.PolicyStatement({
        actions: ['ssm:GetParameter', 'ssm:GetParameters', 'ssm:GetParametersByPath'],
        resources: [`arn:aws:ssm:eu-north-1:${this.account}:parameter/synce/prod/*`],
      }),
    );

    const keyPair = ec2.KeyPair.fromKeyPairName(this, 'KeyPair', 'synce-key');

    const instance = new ec2.Instance(this, 'App', {
      vpc,
      // eu-north-1a had no t4g.micro capacity at deploy time; 1b did.
      vpcSubnets: {
        subnetType: ec2.SubnetType.PUBLIC,
        availabilityZones: [vpc.availabilityZones[1]],
      },
      securityGroup: appSg,
      role,
      keyPair,
      machineImage: ec2.MachineImage.fromSsmParameter(
        '/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64',
      ),
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T4G, ec2.InstanceSize.MICRO),
    });
    instance.addUserData(
      'dnf install -y docker || true',
      'systemctl enable --now docker',
      'usermod -aG docker ec2-user',
      'dnf install -y docker-compose-plugin || (mkdir -p /usr/local/lib/docker/cli-plugins && curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose)',
      'mkdir -p /opt/synce',
    );

    const eip = new ec2.CfnEIP(this, 'Eip');
    new ec2.CfnEIPAssociation(this, 'EipAssoc', {
      instanceId: instance.instanceId,
      allocationId: eip.attrAllocationId,
    });

    const bucket = new s3.Bucket(this, 'PdfBucket', {
      bucketName: `synce-pdf-books-${this.account}`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      removalPolicy: RemovalPolicy.RETAIN,
    });
    bucket.grantReadWrite(role);

    const db = new rds.DatabaseInstance(this, 'Db', {
      engine: rds.DatabaseInstanceEngine.postgres({
        version: rds.PostgresEngineVersion.of('16.15', '16'),
      }),
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [dbSg],
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T4G, ec2.InstanceSize.MICRO),
      allocatedStorage: 20,
      storageType: rds.StorageType.GP3,
      credentials: rds.Credentials.fromPassword(
        'synce',
        cdk.SecretValue.ssmSecure('/synce/prod/db-password', '1'),
      ),
      databaseName: 'synce',
      publiclyAccessible: false,
      storageEncrypted: true,
      // FREE plan caps automated backup retention at 1 day.
      backupRetention: Duration.days(1),
      deletionProtection: false,
    });

    const zone = new route53.PublicHostedZone(this, 'Zone', {
      zoneName: 'synce.natanim.dev',
    });
    new route53.ARecord(this, 'AppDns', {
      zone,
      target: route53.RecordTarget.fromIpAddresses(eip.attrPublicIp),
      ttl: Duration.seconds(300),
    });
    const zoneCfn = zone.node.defaultChild as route53.CfnHostedZone;

    new CfnOutput(this, 'Ec2PublicIp', { value: eip.attrPublicIp });
    new CfnOutput(this, 'RdsEndpoint', { value: db.dbInstanceEndpointAddress });
    new CfnOutput(this, 'BucketName', { value: bucket.bucketName });
    new CfnOutput(this, 'ZoneId', { value: zone.hostedZoneId });
    new CfnOutput(this, 'NameServers', { value: Fn.join(',', zoneCfn.attrNameServers) });
  }
}
