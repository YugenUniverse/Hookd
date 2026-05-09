const mongoose = require('mongoose');

const refreshTokenSchema = new mongoose.Schema({
  tokenId: { type: String, required: true, unique: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  revokedAt: { type: Date, default: null },
  expiresAt: { type: Date, required: true }
}, { timestamps: true });

module.exports = mongoose.model('RefreshToken', refreshTokenSchema);