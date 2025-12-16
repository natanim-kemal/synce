const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://synce:synce@127.0.0.1:5432/synce?schema=public',
});

client.connect()
  .then(() => {
    console.log('Connected successfully');
    return client.end();
  })
  .catch(err => {
    console.error('Connection error', err.stack);
    process.exit(1);
  });
