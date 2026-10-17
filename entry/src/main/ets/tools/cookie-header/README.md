# cookie-header（Cookie 头解析）

请求侧：Cookie 头拆键值对（值不 URL 解码，等号值只切第一个）。
响应侧：Set-Cookie 单条解析属性表（Path/Domain/Max-Age/Secure/HttpOnly/SameSite）。

- 演示的 NGF 层：utils、network
- 纯逻辑：CookieHeaderLogic.ets（CookieHeaderTest.test.ets 5 条）
- 页面：CookieHeaderPage.ets
