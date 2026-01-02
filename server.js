const { spawn } = require('child_process');
const path = require('path');

const port = process.env.PORT || 8080;
const dartBinary = path.join(__dirname, 'build', 'bin', 'server.dart');

// Spawn the Dart process
const dartProcess = spawn('dart', [dartBinary], {
  env: {
    ...process.env,
    PORT: port,
  },
  stdio: 'inherit',
});

dartProcess.on('error', (err) => {
  console.error('Failed to start Dart process:', err);
  process.exit(1);
});

dartProcess.on('exit', (code) => {
  console.log(`Dart process exited with code ${code}`);
  process.exit(code);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  dartProcess.kill('SIGTERM');
});
