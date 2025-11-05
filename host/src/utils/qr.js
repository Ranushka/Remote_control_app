import qrcode from 'qrcode-terminal';

export function renderQr(payload) {
  qrcode.generate(JSON.stringify(payload), { small: true }, code => {
    console.log('\nScan this QR code with the controller app:');
    console.log(code);
  });
}
