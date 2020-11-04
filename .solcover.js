module.exports = {
    testCommand: 'node --max-old-space-size=4096 ../node_modules/.bin/truffle test --network coverage',
    compileCommand: 'node --max-old-space-size=4096 ../node_modules/.bin/truffle compile --network coverage',
    skipFiles: [
        'certificate/ERC1400HoldableCertificateNonceToken',
        'certificate/ERC1400HoldableCertificateSaltToken',
        'certificate/certificateControllers/CertificateControllerNonce',
        'certificate/certificateControllers/CertificateControllerSalt',
        'mocks/CertificateControllerMock',
        'mocks/ERC1400HoldableCertificateTokenMock',
        'mocks/AztecCryptographyEngineMock',
        'tokens/ERC20Token',
        'tokens/ERC721Token',
        'tools/FundIssuer',
    ],
    copyPackages: ['openzeppelin-solidity'],
}
