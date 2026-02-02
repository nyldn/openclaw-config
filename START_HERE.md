# 🚀 Start Here: Test OpenClaw v2.0

Welcome! This guide will get you testing OpenClaw in **under 60 seconds**.

---

## ⚡ Ultra-Quick Start

**Just run these 2 commands:**

```bash
chmod +x test-interactive.sh
./test-interactive.sh
```

That's it! You'll be inside a Docker container ready to test.

---

## 🎯 What Happens Next

1. **Docker builds** a clean Debian 12 environment (~2 minutes)
2. **Container starts** with a welcome message
3. **You test** the installation interactively
4. **You exit** when done (type `exit`)

---

## 📖 First Test (Recommended)

Inside the container, try the new interactive installer:

```bash
./bootstrap.sh --interactive
```

Use **arrow keys** to navigate the menu, **space** to select, **enter** to confirm.

---

## 📚 Full Guides Available

- **[INTERACTIVE_TESTING_GUIDE.md](INTERACTIVE_TESTING_GUIDE.md)** - Complete testing scenarios (10+ pages)
- **[TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md)** - One-page cheat sheet (print this!)

---

## 🎬 Quick Demo

Here's what you'll see:

```
╔════════════════════════════════════════════════════════════╗
║  Welcome to OpenClaw v2.0 Interactive Testing!           ║
╚════════════════════════════════════════════════════════════╝

📍 You are in a clean Debian 12 environment
📁 Repository: ~/openclaw-config

🚀 Quick Start Commands:
  cd ~/openclaw-config/bootstrap
  ./bootstrap.sh --interactive    # Interactive installation
  ./bootstrap.sh --help          # See all options
```

---

## ✨ What's New in v2.0

Test these exciting new features:

1. **Interactive Menus** - Beautiful dialog-based UI
2. **Preset Selection** - Minimal, Developer, Full, or Custom
3. **Auto Dependencies** - Automatically includes required modules
4. **Secret Sanitization** - Redacts API keys in logs
5. **Encrypted Credentials** - AES-256-CBC encryption
6. **Productivity Tools** - Calendar, Email, Tasks, Slack MCP servers

---

## 🏆 Success Looks Like

After installation:

```
╔════════════════════════════════════════════════════════════╗
║  All modules installed successfully                       ║
╚════════════════════════════════════════════════════════════╝

✓ system-deps v1.0.0
✓ python v1.0.0
✓ nodejs v1.0.0

Next steps:
  1. Configure API keys
  2. Test installations
  3. Enjoy OpenClaw!
```

---

## 🔄 Testing Multiple Scenarios

Exit and restart for a fresh environment:

```bash
exit                    # Leave container
./test-interactive.sh   # Start fresh (clean slate)
```

Each run is completely isolated - perfect for testing!

---

## 🎓 Learn More

| File | Purpose | Time to Read |
|------|---------|--------------|
| **This file (START_HERE.md)** | Get started now | 1 min |
| **TESTING_QUICK_REFERENCE.md** | Commands cheat sheet | 2 min |
| **INTERACTIVE_TESTING_GUIDE.md** | Complete scenarios | 10 min |
| **README.md** | Project overview | 5 min |
| **INSTALLATION.md** | Production deployment | 15 min |

---

## 💡 Pro Tips

1. **Start with interactive mode** - It's the easiest way to see what's available
2. **Try minimal install first** - Quick (3-5 min) and validates core functionality
3. **Check the logs** - In `logs/bootstrap-*.log` to see what happened
4. **Validate after install** - Run `./bootstrap.sh --validate` to verify

---

## 🆘 Need Help?

- **Quick questions?** Check [TESTING_QUICK_REFERENCE.md](TESTING_QUICK_REFERENCE.md)
- **Detailed guide?** Read [INTERACTIVE_TESTING_GUIDE.md](INTERACTIVE_TESTING_GUIDE.md)
- **Issues?** Report at https://github.com/nyldn/openclaw-config/issues

---

## 🎉 Ready to Begin?

Run these commands now:

```bash
chmod +x test-interactive.sh
./test-interactive.sh
```

**That's it! You're ready to test OpenClaw v2.0.**

Have fun exploring! 🚀
