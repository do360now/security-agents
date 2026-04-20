# Home Network Security Requirements

**Generated**: 2026-04-19

---

## Context

Home network with:
- Public IP (31.20.234.122) with port forwarding
- Router at 192.168.1.1
- 10 devices (5 local, 5 VPN)
- Standard consumer router with good security headers

---

## Requirements

### REQ-001: Disable Router WAN Management

| Field | Value |
|-------|-------|
| ID | REQ-001 |
| Severity | Critical |
| Target | Router (192.168.1.1) |
| Description | Disable remote/admin access from WAN |
| Threat | Internet-based router compromise |
| Verification | Test: curl http://31.20.234.122/ returns 404 or auth required |

**Specification**: Disable "Remote Management" or "Admin Access from WAN" in router settings.

---

### REQ-002: Router Credential Hardening

| Field | Value |
|-------|-------|
| ID | REQ-002 |
| Severity | High |
| Target | Router admin |
| Description | Change default credentials to strong, unique password |
| Threat | Default credential attacks |
| Verification | Test: Try common defaults (admin/admin, admin/password) — should fail |

**Specification**: Use password manager to generate 20+ char password, store securely.

---

### REQ-003: VPN Connection Audit

| Field | Value |
|-------|-------|
| ID | REQ-003 |
| Severity | High |
| Target | VPN devices |
| Description | Verify all 5 VPN connections (.9, .32, .128, .171, .248) are authorized |
| Threat | Unauthorized remote access |
| Verification | List all VPN users, verify each IP belongs to authorized user |

**Specification**: Check router VPN logs, remove unused accounts, enable MFA.

---

### REQ-004: WAN DNS Blocking

| Field | Value |
|-------|-------|
| ID | REQ-004 |
| Severity | Medium |
| Target | Router port 53 |
| Description | Block DNS port from WAN exposure |
| Threat | DNS amplification attacks |
| Verification | Test: dig @31.20.234.122 should timeout |

**Specification**: Create firewall rule blocking UDP/TCP 53 from WAN.

---

### REQ-005: Port Forwarding Review

| Field | Value |
|-------|-------|
| ID | REQ-005 |
| Severity | Medium |
| Target | Public IP port forwards |
| Description | Remove unnecessary port forwards |
| Threat | Unnecessary attack surface |
| Verification | Test: Only ports 80/443 needed for web services |

**Specification**: Document all port forwards, remove any not in use.

---

### REQ-006: Network Segmentation

| Field | Value |
|-------|-------|
| ID | REQ-006 |
| Severity | Medium |
| Target | LAN devices |
| Description | Separate IoT/guest devices from main network |
| Threat | Lateral movement after single device compromise |
| Verification | Test: IoT devices cannot access main network resources |

**Specification**: Use guest network or VLAN for IoT devices.

---

## Mythos-Class Requirements

### REQ-M1: AI-Driven Reconnaissance Detection

| Field | Value |
|-------|-------|
| ID | REQ-M1 |
| Severity | Medium |
| Description | Detect automated scanning from internet |
| Specification | Log failed auth attempts, port scans; alert on pattern |

---

### REQ-M2: Rapid Incident Response

| Field | Value |
|-------|-------|
| ID | REQ-M2 |
| Severity | High |
| Description | Ability to quickly isolate compromised devices |
| Specification | Document network kill switch, VPN disconnect procedure |

---

## Prioritization

| Priority | Requirements |
|----------|--------------|
| P0 | REQ-001, REQ-002 |
| P1 | REQ-003, REQ-004, REQ-005, REQ-M2 |
| P2 | REQ-006, REQ-M1 |