# Home Network Security Solutions

**Generated**: 2026-04-19

---

## Solution Summary

| Solution | Targets | Priority |
|----------|---------|----------|
| SOL-001 | Disable WAN router admin | P0 |
| SOL-002 | Change router credentials | P0 |
| SOL-003 | VPN audit + MFA | P1 |
| SOL-004 | Block WAN DNS | P1 |
| SOL-005 | Port forwarding audit | P1 |
| SOL-006 | Network segmentation | P2 |

---

## SOL-001: Disable WAN Router Admin

| Field | Value |
|-------|-------|
| ID | SOL-001 |
| Targets | RISK-001 |
| Type | Prevent |
| Priority | P0 |

### Implementation

1. Login to router admin (192.168.1.1)
2. Find "Remote Management", "Admin Access", or "WAN Access" setting
3. **Disable** remote management from WAN/internet
4. Save and apply

**Verification**:
```bash
# Should fail or return different content
curl -I http://31.20.234.122/
```

---

## SOL-002: Router Credential Hardening

| Field | Value |
|-------|-------|
| ID | SOL-002 |
| Targets | RISK-003 |
| Type | Prevent |
| Priority | P0 |

### Implementation

1. Login to router admin
2. Navigate to admin password settings
3. Generate strong password (20+ characters, use password manager)
4. Set new password
5. **Backup** password in secure location (1Password, Bitwarden, etc.)

**Password requirements**:
- Length: 20+ characters
- No dictionary words
- Mix: uppercase, lowercase, numbers, symbols
- Unique: never used elsewhere

---

## SOL-003: VPN Connection Audit + MFA

| Field | Value |
|-------|-------|
| ID | SOL-003 |
| Targets | RISK-002 |
| Type | Detect + Prevent |
| Priority | P1 |

### Implementation

1. Login to router admin
2. Find "VPN", "Remote Access", or "OpenVPN/PPTP" settings
3. List all VPN users/connections
4. **Verify each** IP address (.9, .32, .128, .171, .248) belongs to authorized user
5. Remove any unused accounts
6. **Enable MFA** if router supports (or use VPN provider with MFA)
7. Document authorized VPN users

---

## SOL-004: Block WAN DNS

| Field | Value |
|-------|-------|
| ID | SOL-004 |
| Targets | RISK-004 |
| Type | Prevent |
| Priority | P1 |

### Implementation

1. Login to router admin
2. Find "Firewall" or "Port Forwarding" settings
3. Create rule: **Block** incoming UDP/TCP on port 53 from WAN
4. Save and apply

**Alternative**: If router doesn't support, contact ISP about blocking port 53

---

## SOL-005: Port Forwarding Audit

| Field | Value |
|-------|-------|
| ID | SOL-005 |
| Targets | RISK-007 |
| Type | Prevent |
| Priority | P1 |

### Implementation

1. Login to router admin
2. Find "Port Forwarding" or "Virtual Server" settings
3. **Document** all current forwards:
   - Public port → Internal IP:port
   - Purpose
4. **Remove** any not actively used
5. Keep minimal: only 80/443 if needed for web access

---

## SOL-006: Network Segmentation

| Field | Value |
|-------|-------|
| ID | SOL-006 |
| Targets | RISK-005, RISK-006 |
| Type | Prevent |
| Priority | P2 |

### Implementation

**Option A: Guest Network (Easiest)**
1. Router settings → "Guest Network" or "Isolated Network"
2. Enable guest network
3. Connect IoT devices to guest network
4. Verify guest devices cannot access main network

**Option B: VLAN (Advanced)**
- Requires router with VLAN support
- Create separate VLAN for IoT (e.g., VLAN 20)
- Configure firewall between VLANs

**Devices to isolate**:
- Smart TVs
- Thermostats, smart home
- Network cameras
- Printers

---

## Implementation Roadmap

| Step | Solution | Effort | Dependencies |
|------|----------|--------|---------------|
| 1 | SOL-001 (Disable WAN admin) | 5 min | Router access |
| 2 | SOL-002 (Change credentials) | 5 min | Password manager |
| 3 | SOL-003 (VPN audit) | 15 min | List of authorized users |
| 4 | SOL-004 (Block DNS) | 5 min | Router firewall |
| 5 | SOL-005 (Port audit) | 10 min | Documented forwards |
| 6 | SOL-006 (Segmentation) | 30-60 min | Router guest network |

**Total**: ~1.5 hours

---

## Verification

Run these after implementing fixes:

```bash
# Test WAN admin disabled
curl -I http://31.20.234.122/
# Expected: Connection refused or different content

# Test DNS blocked from WAN
timeout 3 dig @31.20.234.122 google.com
# Expected: Timeout or SERVFAIL
```

---

## Emergency Response

If router is compromised:
1. **Immediately** disconnect router from WAN (unplug cable/DSL)
2. Power cycle router (restore to defaults if unsure)
3. Change all network passwords
4. Check connected devices for compromise
5. Reconfigure with security fixes above
6. Monitor for suspicious activity