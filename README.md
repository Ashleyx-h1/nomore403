# 🔥 403 Bypass Tester

Simple Bash script to test **403/401/404 bypass techniques** using headers, methods, and path tricks.

---

## 🚀 Usage

```bash
./script.sh -u https://target.com -e /admin
```

With auth:
```bash
./script.sh -u https://target.com -e /admin -H "Cookie: session=abc; Authorization: Bearer token"
```

---

## ⚙️ Features

- Header bypass (X-Original-URL, X-Forwarded-*, etc.)
- URL override via `/`
- Method testing (GET, POST, PUT, DELETE, HEAD, TRACE)
- Method override headers
- Path fuzzing (`%00`, `%2e`, `..;/`)
- Double encoding
- Custom headers (`-H`)
- Colored output
- Smart bypass detection

---

## 🎯 Valid Bypass

- `403 → 200`
- `401 → 200`
- `404 → 200`
- `403 → 302`

Also:
- Same status + big size difference

---

## ❌ Not a Bypass

- `403 → 404`
- `404 → 400`
- `403 → 403`

---

## 🧪 Example

```bash
[Path: /admin%00] => Status: 200 | Size: 842
>>> POSSIBLE BYPASS using: https://target.com/admin%00
```

---

## ⚠️ Notes

- Use on protected endpoints (`/admin`, `/internal`)
- Verify manually (Burp)
- Most targets won’t be vulnerable

---

## ⚖️ Disclaimer

For authorized testing only.
