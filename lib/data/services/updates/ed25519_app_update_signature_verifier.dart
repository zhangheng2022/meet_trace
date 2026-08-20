import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'signed_app_update_manifest_parser.dart';

final class Ed25519AppUpdateSignatureVerifier
    implements AppUpdateManifestSignatureVerifier {
  Ed25519AppUpdateSignatureVerifier({
    required this.expectedKeyId,
    required List<int> publicKeyBytes,
    Ed25519? algorithm,
  }) : publicKey = SimplePublicKey(
         List<int>.unmodifiable(publicKeyBytes),
         type: KeyPairType.ed25519,
       ),
       algorithm = algorithm ?? Ed25519();

  final String expectedKeyId;
  final SimplePublicKey publicKey;
  final Ed25519 algorithm;

  @override
  Future<bool> verify({
    required Uint8List signedPayload,
    required String algorithm,
    required String keyId,
    required Uint8List signature,
  }) async {
    if (algorithm != 'Ed25519' ||
        keyId != expectedKeyId ||
        signature.length != 64) {
      return false;
    }
    return this.algorithm.verify(
      signedPayload,
      signature: Signature(signature, publicKey: publicKey),
    );
  }
}
