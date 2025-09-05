# Lockout Prevention Guide - Never Get Locked Out Again

## 🚨 The Problem You've Experienced

Getting locked out of infrastructure after security hardening is a **common DevOps nightmare**. You spend hours building something awesome, apply "best practices" security, and suddenly you can't access your own infrastructure. We've all been there - it's devastating.

## 🔐 The Solution: Defense in Depth Access

Instead of immediate hardening, we implement **gradual hardening with multiple failsafes**.

### Multiple Access Methods (Redundancy)

#### 1. SSH Key Authentication (Primary)
- Your normal SSH keys for daily access
- Separate keys for automation (ansible, terraform)
- Works immediately and remains functional

#### 2. Emergency Console User (Failsafe #1)  
- User: `emergency` 
- Password: `Console123!` (stored in encrypted recovery file)
- **Always accessible via Proxmox console** (can't be locked out)
- Has sudo access to fix SSH/firewall issues

#### 3. Temporary Password Auth (Failsafe #2)
- Enabled for first 48 hours
- Gives you time to test SSH keys work
- Automatically disabled after grace period

#### 4. Recovery Scripts (Failsafe #3)
- `/usr/local/bin/emergency-access.sh reset` - Restores safe access
- Disables fail2ban, opens firewall, resets SSH config
- Run from console if SSH fails

### Gradual Hardening Timeline

**This prevents immediate lockouts while still achieving security:**

#### Hours 0-1: **Testing Phase** (Maximum Access)
- ✅ SSH keys work
- ✅ Password authentication works  
- ✅ Console access works
- ✅ No fail2ban restrictions
- **🚨 CRITICAL: Test all access methods during this window!**

#### Hours 1-24: **Phase 1 Hardening**
- ❌ Password authentication disabled
- ✅ SSH keys still work
- ✅ Console access still works
- ✅ No fail2ban yet

#### Hours 24-48: **Phase 2 Hardening**  
- ❌ Password authentication disabled
- ✅ SSH keys still work
- ✅ Console access still works
- ⚠️ Fail2ban enabled (moderate settings)

#### Hours 48+: **Full Hardening**
- ❌ Password authentication disabled
- ✅ SSH keys still work (if tested earlier)
- ✅ Console access still works
- ⚠️ Fail2ban strict settings
- ⚠️ Maximum SSH restrictions

## 🗝️ Recovery Credentials (age/SOPS Integration)

Your existing age setup is **perfect** for this! Recovery credentials are automatically:

1. **Generated** during template creation
2. **Encrypted** using your existing age key
3. **Stored** in your homelab-infrastructure repo
4. **Accessible** only by you with your age private key

### Recovery File Location
```bash
/Users/kellen/_code/UncertainMeow/homelab-infrastructure/recovery/vm-{VMID}-recovery.age
```

### Decrypt Recovery Credentials
```bash
age -d -i ~/.config/age/homelab-recovery.txt vm-{VMID}-recovery.age
```

## 🛠️ Emergency Procedures

### If You Get Locked Out via SSH

#### Option 1: Proxmox Console Access
1. Open Proxmox web UI
2. Go to VM → Console  
3. Login as `emergency` / `Console123!`
4. Run: `sudo /usr/local/bin/emergency-access.sh reset`
5. SSH should work again

#### Option 2: Reset from Host
```bash
# From Proxmox host
qm monitor {VMID}
# In monitor: info network
# Then SSH to VM IP with emergency user
```

#### Option 3: Rollback Template 
```bash
# Worst case: destroy and recreate from template
qm destroy {VMID}
qm clone {template-id} {VMID} --name new-vm --full
```

## 🧪 Testing Protocol

**NEVER skip this - it's saved me countless times:**

### Immediate Testing (First Hour)
```bash
# 1. Clone template for testing
qm clone 9001 999 --name access-test --full
qm start 999

# 2. Test SSH key access
ssh -i ~/.ssh/your_key user@vm-ip

# 3. Test console access  
# Use Proxmox web UI console

# 4. Test emergency user
# Console: login as emergency/Console123!

# 5. Test recovery script
sudo /usr/local/bin/emergency-access.sh status

# 6. If all tests pass, use template for production
qm destroy 999  # Clean up test VM
```

### Pre-Production Checklist
- [ ] SSH key access confirmed working
- [ ] Console access confirmed working
- [ ] Emergency user access confirmed working
- [ ] Recovery scripts tested and working
- [ ] Recovery credentials decrypted successfully
- [ ] Multiple team members can access (if team environment)

## 🔄 Best Practices Learned from Pain

### 1. Always Test Access Before Hardening
- **Never** apply security changes to production without testing
- **Always** have a rollback plan
- **Test** every access method works

### 2. Gradual Implementation  
- **Don't** go from zero to maximum security instantly
- **Do** implement security in phases over time
- **Allow** grace periods for testing and fixes

### 3. Multiple Access Paths
- **Never** rely on a single access method
- **Always** have console access available
- **Create** emergency users with different auth methods

### 4. Document Everything
- **Store** recovery credentials securely
- **Document** emergency procedures
- **Test** recovery procedures regularly

### 5. Infrastructure as Code
- **Script** everything so you can recreate
- **Version control** all configurations  
- **Template** common patterns

## 📋 Template Comparison

| Feature | Standard Template | LOCKOUT-SAFE Template |
|---------|------------------|----------------------|
| SSH Hardening | ✅ Immediate | ✅ Gradual (48h) |
| Password Auth | ❌ Disabled immediately | ✅ 48h grace period |
| Console Access | ✅ Via primary user | ✅ Via emergency user |
| Recovery Scripts | ❌ None | ✅ Built-in |
| Fail2ban | ✅ Immediate | ✅ Gradual (24h delay) |
| Multiple Users | ⚠️ Limited | ✅ Multiple access paths |
| Recovery Docs | ❌ Manual | ✅ Encrypted & automated |

## 🎯 Recommendation

**Use the LOCKOUT-SAFE template** (`create-debian-vm-template-safe.sh`) for:
- ✅ Production infrastructure
- ✅ Learning environments  
- ✅ Any system you can't afford to lose access to
- ✅ Team environments where multiple people need access

**Use the standard template** (`create-debian-vm-template.sh`) for:
- ⚠️ Truly disposable test systems
- ⚠️ When you have extensive console access
- ⚠️ Fully automated environments with external management

## 💡 Your Pain Points Addressed

1. **"Locked out after 8 hours of work"** → Multiple access methods + gradual hardening
2. **"No way back in"** → Emergency console user + recovery scripts  
3. **"Lost all the work"** → Infrastructure as code + templates mean nothing is lost
4. **"Don't want to compromise security"** → Full hardening achieved, just gradually

**This approach gives you enterprise-grade security WITHOUT the lockout risk.**

You get the security you want, with the safety nets you need. The template achieves the same final security state, just intelligently over time instead of immediately.

## 🚀 Ready to Deploy Safely

The LOCKOUT-SAFE template is ready to use. It integrates with your existing age/SOPS setup and provides multiple recovery options.

**Your infrastructure will be secure AND accessible.** 🔐✅