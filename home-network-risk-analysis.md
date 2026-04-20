# Home Network Risk Analysis

**Generated**: 2026-04-19

---

## Risk Matrix

| Risk ID | Description | Likelihood | Impact | Severity |
|---------|-------------|-----------|--------|----------|
| RISK-001 | Router WAN admin compromise | Medium | Critical | **Critical** |
| RISK-002 | Unauthorized VPN access | Medium | High | **High** |
| RISK-003 | Default credentials used | Medium | High | **High** |
| RISK-004 | DNS amplification from WAN | Low | Medium | **Medium** |
| RISK-005 | IoT device compromise | Medium | Medium | **Medium** |
| RISK-006 | Lateral movement (no segmentation) | Medium | Medium | **Medium** |
| RISK-007 | Port forwarding exploitation | Low | High | **Medium** |

---

## Detailed Risk Analysis

### RISK-001: Router WAN Admin Compromise

**Threat**: Attacker accesses router admin from internet via port forwarding.

**Attack Chain**:
1. Scan public IP → find open port 80/443
2. Identify router model via HTTP headers
3. Exploit known CVE OR use default credentials
4. Change DNS settings → traffic hijacking
5. Full network compromise

**Likelihood**: Medium — port is open, router model identifiable
**Impact**: Critical — entire network compromised
**Mitigation**: Disable remote admin from WAN

---

### RISK-002: Unauthorized VPN Access

**Threat**: Unknown VPN connections (.9, .32, .128, .171, .248) provide internet-to-LAN tunnel.

**Attack Chain**:
1. Stolen VPN credentials OR compromised remote device
2. Establish VPN tunnel bypassing firewall
3. Lateral movement to all LAN devices
4. Data theft, ransomware, botnet

**Likelihood**: Low (if VPN secured) to High (if credentials leaked)
**Impact**: High — direct internal access
**Mitigation**: MFA on VPN, audit connections

---

### RISK-003: Default Credentials

**Threat**: Router still using factory defaults (admin/admin, etc.)

**Likelihood**: Medium — common oversight
**Impact**: High — full router control

---

### RISK-005: IoT Device Compromise

**Threat**: Smart devices (likely at .71, .227) have vulnerabilities.

**Attack Chain**:
1. Exploit IoT vulnerability (common in cameras, TVs, thermosts)
2. Use as pivot to main network
3. Deploy malware, exfil data, join botnet

**Likelihood**: Medium — IoT devices rarely updated
**Impact**: Medium — limited by device capabilities

---

## Red Team Tests

### RT-001: Router WAN Admin Test

```bash
# Should fail if remote admin disabled
curl -I http://31.20.234.122/
# Check for router login page in response
```

### RT-002: DNS WAN Test

```bash
# Should timeout/block if DNS disabled on WAN
dig @31.20.234.122 google.com +short
```

### RT-003: Credential Guessing

```bash
# Try default credentials (DO NOT run - educational only)
# admin:admin, admin:password, admin:1234, root:root
```

### RT-004: VPN Log Review

```bash
# Check router VPN logs for unknown IPs
# (Access router admin panel required)
```

---

## Mythos-Era Context

For Mythos-class AI, home networks are **low-value targets** but still relevant:

**Why target home networks?**
- VPN credentials for pivot to corporate networks
- Cryptocurrency wallets
- Personal data for extortion
- Botnet recruitment

**What would Mythos do?**
1. Scan public IP range for exposed services
2. Identify router vendor/model
3. Search for known vulnerabilities
4. Attempt default credentials
5. Use compromised router for DNS hijacking
6. Pivot to connected devices

**Defense priority**: Make it not worth the effort — disable WAN admin, use strong credentials, MFA on VPN.

---

## Chaining Analysis

**Attack Chain Potential**:

```
Internet → Router (WAN admin) → DNS hijack → All traffic compromised
Internet → VPN → Lateral movement → Corporate network access
Compromised IoT → Main network → Data exfiltration
```

**Mitigation Priority**: Break earliest link in chain (disable WAN admin)