/**
 * 端口速查的纯逻辑实现（本地数据表，与 port-tester 互补——那是连通测试，这是用途查询）。
 *
 * @module tools/port-lookup/PortLookup
 */

import { NGFLocalizedText } from '../../core/ToolModel';

function wrapName(name: string): NGFLocalizedText {
  return new NGFLocalizedText(name, name);
}

/** 一条端口映射 */
export class PortEntry {
  readonly port: number;
  readonly name: NGFLocalizedText;
  readonly meaning: NGFLocalizedText;

  constructor(port: number, name: NGFLocalizedText, meaning: NGFLocalizedText) {
    this.port = port;
    this.name = name;
    this.meaning = meaning;
  }
}

/** 查询结果 */
export class PortLookupResult {
  readonly entries: Array<PortEntry>;

  constructor(entries: Array<PortEntry>) {
    this.entries = entries;
  }
}

function buildTable(): Array<PortEntry> {
  const list: Array<PortEntry> = [];
  const add = (port: number, name: string, meaning: NGFLocalizedText): void => {
  list.push(new PortEntry(port, wrapName(name), meaning));
  };
  add(20, 'FTP-DATA', new NGFLocalizedText('FTP 数据传输', 'FTP data transfer'));
  add(21, 'FTP', new NGFLocalizedText('FTP 控制连接', 'FTP control connection'));
  add(22, 'SSH', new NGFLocalizedText('SSH 远程登录 / SCP / SFTP', 'SSH remote login, SCP and SFTP'));
  add(23, 'Telnet', new NGFLocalizedText('Telnet 远程登录（明文，不安全）', 'Telnet remote login (plain text, insecure)'));
  add(25, 'SMTP', new NGFLocalizedText('邮件发送', 'Mail sending'));
  add(53, 'DNS', new NGFLocalizedText('域名解析', 'DNS lookup'));
  add(80, 'HTTP', new NGFLocalizedText('网页（明文）', 'Web (plain text)'));
  add(110, 'POP3', new NGFLocalizedText('邮件接收（明文）', 'Mail retrieval (plain text)'));
  add(143, 'IMAP', new NGFLocalizedText('邮件接收（明文）', 'Mail retrieval (plain text)'));
  add(443, 'HTTPS', new NGFLocalizedText('网页（TLS 加密）', 'Web (TLS encrypted)'));
  add(445, 'SMB', new NGFLocalizedText('Windows 文件共享', 'Windows file sharing'));
  add(465, 'SMTPS', new NGFLocalizedText('邮件发送（TLS）', 'Mail sending (TLS)'));
  list.push(new PortEntry(587,
    new NGFLocalizedText('SMTP 提交', 'SMTP submission'),
    new NGFLocalizedText('邮件提交（STARTTLS）', 'Mail submission (STARTTLS)')));
  add(993, 'IMAPS', new NGFLocalizedText('邮件接收（TLS）', 'Mail retrieval (TLS)'));
  add(995, 'POP3S', new NGFLocalizedText('邮件接收（TLS）', 'Mail retrieval (TLS)'));
  add(1433, 'SQL Server', new NGFLocalizedText('微软数据库', 'Microsoft SQL Server'));
  add(1521, 'Oracle', new NGFLocalizedText('Oracle 数据库', 'Oracle database'));
  add(2375, 'Docker API', new NGFLocalizedText('Docker 远程 API（明文）', 'Docker remote API (plain text)'));
  add(3306, 'MySQL', new NGFLocalizedText('MySQL 数据库', 'MySQL database'));
  add(3389, 'RDP', new NGFLocalizedText('远程桌面', 'Remote desktop'));
  add(5432, 'PostgreSQL', new NGFLocalizedText('PostgreSQL 数据库', 'PostgreSQL database'));
  add(5672, 'AMQP', new NGFLocalizedText('RabbitMQ 消息队列', 'RabbitMQ message queue'));
  add(6379, 'Redis', new NGFLocalizedText('Redis 数据库', 'Redis database'));
  list.push(new PortEntry(8080,
    new NGFLocalizedText('HTTP 备用', 'HTTP alternate'),
    new NGFLocalizedText('常见 Web 开发/代理端口', 'Common web dev and proxy port')));
  list.push(new PortEntry(8443,
    new NGFLocalizedText('HTTPS 备用', 'HTTPS alternate'),
    new NGFLocalizedText('HTTPS 备用端口', 'Alternate HTTPS port')));
  add(9200, 'Elasticsearch', new NGFLocalizedText('Elasticsearch REST API', 'Elasticsearch REST API'));
  add(27017, 'MongoDB', new NGFLocalizedText('MongoDB 数据库', 'MongoDB database'));
  list.push(new PortEntry(3000,
    new NGFLocalizedText('开发服务', 'Dev server'),
    new NGFLocalizedText('常见前端/框架开发端口', 'Common frontend dev port')));
  list.push(new PortEntry(5000,
    new NGFLocalizedText('开发服务', 'Dev server'),
    new NGFLocalizedText('常见 Flask/调试端口', 'Common Flask and debug port')));
  list.push(new PortEntry(9090,
    new NGFLocalizedText('管理面板', 'Admin console'),
    new NGFLocalizedText('常见管理控制台端口', 'Common admin console port')));
  return list;
}

const TABLE: Array<PortEntry> = buildTable();

/** 全表 */
export function allPortEntries(): Array<PortEntry> {
  return TABLE;
}

/** 查询：端口号（精确或前缀）或服务名/用途模糊 */
export function queryPorts(keyword: string): PortLookupResult {
  const text: string = keyword.trim().toLowerCase();
  const out: Array<PortEntry> = [];
  for (let i = 0; i < TABLE.length; i++) {
    const e: PortEntry = TABLE[i];
    if (text.length === 0) {
      out.push(e);
      continue;
    }
    const isNumeric: boolean = /^[0-9]+$/.test(text);
    if (isNumeric) {
      if (String(e.port).indexOf(text) === 0) {
        out.push(e);
      }
    } else if (e.name.zh.indexOf(keyword.trim()) >= 0 || e.name.en.toLowerCase().indexOf(text) >= 0 ||
      e.meaning.zh.indexOf(keyword.trim()) >= 0 || e.meaning.en.toLowerCase().indexOf(text) >= 0) {
      out.push(e);
    }
  }
  return new PortLookupResult(out);
}
