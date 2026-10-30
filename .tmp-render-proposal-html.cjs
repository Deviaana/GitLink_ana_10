const fs = require("node:fs");
const path = require("node:path");

const root = process.cwd();
const extensionRoot =
  "C:/Users/Lenovo/.vscode/extensions/yzane.markdown-pdf-1.5.0";
const MarkdownIt = require(path.join(extensionRoot, "node_modules", "markdown-it"));

const markdownStyles = fs.readFileSync(
  "C:/Users/Lenovo/.vscode/extensions/yzane.markdown-pdf-2.2.0/styles/markdown.css",
  "utf8",
);
const pdfStyles = fs.readFileSync(
  "C:/Users/Lenovo/.vscode/extensions/yzane.markdown-pdf-2.2.0/styles/markdown-pdf.css",
  "utf8",
);
const source = fs.readFileSync(path.join(root, "docs", "proposal.md"), "utf8");
const content = new MarkdownIt({ html: true, linkify: true }).render(source);
const date = new Date().toISOString().slice(0, 10);
const html = `<!DOCTYPE html>
<html>
<head>
<title>proposal.md</title>
<meta http-equiv="Content-type" content="text/html;charset=UTF-8">
<style>
${markdownStyles}
${pdfStyles}
@page { size: A4; margin: 0; }
body {
  font-family: "Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI", sans-serif;
  padding: 1.5cm calc(1cm + 12px) 1cm;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.print-header, .print-footer {
  position: fixed;
  left: 1cm;
  right: 1cm;
  color: #666;
  font: 9px "Segoe UI", "Microsoft YaHei UI", sans-serif;
}
.print-header { top: 0.85cm; display: flex; justify-content: space-between; }
.print-footer { bottom: 0.55cm; text-align: center; }
</style>
</head>
<body class="vscode-light">
<div class="print-header"><span>proposal.md</span><span>${date}</span></div>
${content}
<div class="print-footer">1 / 1</div>
</body>
</html>`;

fs.writeFileSync(path.join(root, ".tmp-proposal.html"), html);
