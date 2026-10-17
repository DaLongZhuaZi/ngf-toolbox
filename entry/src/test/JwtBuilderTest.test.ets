import { describe, expect, it } from '@ohos/hypium';
import {
  buildJwt,
  toBase64Url,
  JwtBuildFailureCode
} from '../main/ets/tools/jwt-builder/JwtBuilderLogic';

/**
 * JWT 构建的单测：**JWT.io 官方示例向量**。
 * payload {"sub":"1234567890","name":"John Doe","iat":1516239022} +
 * secret your-256-bit-secret → eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIi...
 */
export default function jwtBuilderTest() {
  describe('jwtBuilderTest', () => {
    it('JWT.io 官方向量：token 前两段与官方一致', 0, () => {
      const payload = '{"sub":"1234567890","name":"John Doe","iat":1516239022}';
      const r = buildJwt(payload, 'your-256-bit-secret');
      expect(r.ok).assertEqual(true);
      expect(r.headerB64).assertEqual('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9');
      expect(r.payloadB64).assertEqual('eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ');
      // 官方签名前缀（完整签名以 ConxAj 开头）
      expect(r.signatureB64).assertEqual('SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c');
      expect(r.token.indexOf('.') === 36).assertEqual(true);
    });

    it('toBase64Url：加号/斜杠/填充', 0, () => {
      expect(toBase64Url('a+b/c==')).assertEqual('a-b_c');
      expect(toBase64Url('ab')).assertEqual('ab');
    });

    it('空 payload/空 secret/bad JSON 报错', 0, () => {
      expect(buildJwt('', 'k').failure.code).assertEqual(JwtBuildFailureCode.EMPTY_PAYLOAD);
      expect(buildJwt('{"a":1}', '').failure.code).assertEqual(JwtBuildFailureCode.EMPTY_SECRET);
      expect(buildJwt('{bad', 'k').failure.code).assertEqual(JwtBuildFailureCode.BAD_PAYLOAD_JSON);
    });

    it('token 结构：三段两圆点', 0, () => {
      const r = buildJwt('{"a":1}', 'secret');
      expect(r.token.split('.').length).assertEqual(3);
    });
  });
}
