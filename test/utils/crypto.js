const crypto = require("crypto")

// Format required for sending bytes through eth client:
//  - hex string representation
//  - prefixed with 0x
const bufToStr = b => '0x' + b.toString('hex')

const random32 = () => crypto.randomBytes(32)

const sha256 = x =>
  crypto
    .createHash('sha256')
    .update(x)
    .digest()

const newSecretHashPair = () => {
  const secret = random32()
  const hash = sha256(secret)
  return {
    secret: bufToStr(secret),
    hash: bufToStr(hash),
  }
}

const newHoldId = () => {
  return bufToStr(random32())
}

module.exports = { bufToStr, random32, newSecretHashPair, newHoldId }