import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

/// Simple encryption service that generates an RSA keypair per device,
/// stores the private key securely, publishes the public key (caller must
/// upload to server), and provides helpers to encrypt/decrypt messages
/// using hybrid RSA (encrypt AES key with RSA and payload with AES).
class EncryptionService {
  static final EncryptionService instance = EncryptionService._();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static const _privateKeyKey = 'e2e_rsa_private_pem';
  static const _publicKeyKey = 'e2e_rsa_public_pem';

  EncryptionService._();

  Future<bool> hasKeys() async {
    final pk = await _secure.read(key: _privateKeyKey);
    return pk != null;
  }

  Future<void> generateAndStoreKeyPair({int bitLength = 2048}) async {
    // Generate RSA keypair using PointyCastle
    final keyParams = pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64);
    final secureRandom = _getSecureRandom();
    final rngParams = pc.ParametersWithRandom(keyParams, secureRandom);
    final kgen = pc.RSAKeyGenerator();
    kgen.init(rngParams);
    final pair = kgen.generateKeyPair();
    final pc.RSAPublicKey publicKey = pair.publicKey as pc.RSAPublicKey;
    final pc.RSAPrivateKey privateKey = pair.privateKey as pc.RSAPrivateKey;

    final publicPem = CryptoUtils.encodeRSAPublicKeyToPemPkcs1(publicKey);
    final privatePem = CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey);

    await _secure.write(key: _privateKeyKey, value: privatePem);
    await _secure.write(key: _publicKeyKey, value: publicPem);
  }

  Future<String?> getPublicKeyPem() async => await _secure.read(key: _publicKeyKey);
  Future<String?> getPrivateKeyPem() async => await _secure.read(key: _privateKeyKey);

  pc.SecureRandom _getSecureRandom() {
    final secureRandom = pc.FortunaRandom();
    final seed = Uint8List(32);
    final rnd = Random.secure();
    for (int i = 0; i < seed.length; i++) {
      seed[i] = rnd.nextInt(256);
    }
    secureRandom.seed(pc.KeyParameter(seed));
    return secureRandom;
  }

  /// Encrypt plaintext for recipient's public key (PEM). Returns a base64 JSON
  /// containing: { key: base64(rsa_encrypted_aes_key), iv: base64(iv), payload: base64(aes_cipher) }
  Future<String> encryptForRecipient(String plaintext, String recipientPublicPem) async {
    // generate AES key & IV
    final aesKey = encrypt_pkg.Key.fromSecureRandom(32);
    final iv = encrypt_pkg.IV.fromSecureRandom(16);

    final aesEncrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(aesKey, mode: encrypt_pkg.AESMode.cbc));
    final encrypted = aesEncrypter.encrypt(plaintext, iv: iv);

  // Encrypt AES key with recipient RSA public key using OAEP (PointyCastle)
  final pc.RSAPublicKey recipientPcPub = CryptoUtils.rsaPublicKeyFromPem(recipientPublicPem);
  final oaepEnc = pc.OAEPEncoding(pc.RSAEngine());
  oaepEnc.init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(recipientPcPub));
  final encryptedKey = oaepEnc.process(Uint8List.fromList(aesKey.bytes));

    final envelope = {
      'key': base64Encode(encryptedKey),
      'iv': base64Encode(iv.bytes),
      'payload': base64Encode(encrypted.bytes),
    };
    return base64Encode(utf8.encode(jsonEncode(envelope)));
  }

  /// Decrypt message envelope (base64 json) using stored private key
  Future<String> decryptEnvelope(String envelopeB64) async {
    final privatePem = await getPrivateKeyPem();
    if (privatePem == null) throw Exception('Private key not found');

    final raw = utf8.decode(base64Decode(envelopeB64));
    final Map<String, dynamic> map = jsonDecode(raw);
    final encryptedKey = base64Decode(map['key']);
    final iv = encrypt_pkg.IV(base64Decode(map['iv']));
    final payload = base64Decode(map['payload']);

  final pc.RSAPrivateKey privKey = CryptoUtils.rsaPrivateKeyFromPem(privatePem);
  final oaepDec = pc.OAEPEncoding(pc.RSAEngine());
  oaepDec.init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privKey));
  final decryptedKeyBytes = oaepDec.process(encryptedKey);

  final aesKey = encrypt_pkg.Key(Uint8List.fromList(decryptedKeyBytes));
    final aesEncrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(aesKey, mode: encrypt_pkg.AESMode.cbc));
    final decrypted = aesEncrypter.decryptBytes(encrypt_pkg.Encrypted(payload), iv: iv);

    return utf8.decode(decrypted);
  }
}
