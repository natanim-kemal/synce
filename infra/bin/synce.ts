import { App } from 'aws-cdk-lib';
import { SynceStack } from '../lib/synce-stack';

const app = new App();
new SynceStack(app, 'SynceStack', {
  env: { account: '179530538522', region: 'eu-north-1' },
});
app.synth();
