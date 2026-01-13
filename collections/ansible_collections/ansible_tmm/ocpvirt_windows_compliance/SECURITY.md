# Security Best Practices

This document outlines security considerations for using the `ansible_tmm.ocpvirt_windows_compliance` collection.

## Credential Management

### Never Commit Secrets to Git

The following files should **NEVER** be committed to version control:

- `vault.yml` - Use `vault.yml.example` as a template
- `credentials.yml`
- `secrets.yml`
- `.env` files
- SSH private keys
- Certificates and private keys

The `.gitignore` file is configured to exclude these files, but always verify before committing.

### Using Ansible Vault

1. **Create an encrypted vault file:**
   ```bash
   # Copy the example
   cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml

   # Edit with your values
   vim inventory/group_vars/all/vault.yml

   # Encrypt the file
   ansible-vault encrypt inventory/group_vars/all/vault.yml
   ```

2. **Reference vault variables in playbooks:**
   ```yaml
   ansible_password: "{{ vault_windows_admin_password }}"
   ```

3. **Run playbooks with vault:**
   ```bash
   ansible-playbook playbook.yml --ask-vault-pass
   # or
   ansible-playbook playbook.yml --vault-password-file ~/.vault_pass
   ```

### Using AAP Credentials

In Ansible Automation Platform, store credentials using the built-in credential management:

1. **Machine Credentials** - For Windows/Linux authentication
2. **OpenShift Credentials** - For Kubernetes API access
3. **Vault Credentials** - For Ansible Vault passwords
4. **Custom Credentials** - For API tokens and other secrets

**Never** store credentials in:
- Job template variables
- Project files
- Inventory variables (unless encrypted)

## Sysprep / autounattend.xml Files

The autounattend.xml files in `files/sysprep/` contain placeholder passwords:

```xml
<Value>CHANGE_ME_BEFORE_USE</Value>
```

**Before using these files:**

1. Search for `CHANGE_ME_BEFORE_USE` and replace with a secure password
2. Consider using a secrets management solution
3. For production, consider:
   - Using certificate-based authentication instead of passwords
   - Rotating passwords after initial setup
   - Using temporary passwords that are changed on first login

## WinRM Security

### Development/Testing

For testing, you may use HTTP (port 5985) with basic authentication:

```yaml
ansible_port: 5985
ansible_winrm_transport: basic
```

### Production

For production environments:

1. **Use HTTPS (port 5986):**
   ```yaml
   ansible_port: 5986
   ansible_winrm_server_cert_validation: validate  # or use proper CA certs
   ```

2. **Use NTLM or Kerberos instead of Basic auth:**
   ```yaml
   ansible_winrm_transport: ntlm  # or kerberos
   ```

3. **Disable unencrypted traffic on Windows:**
   ```powershell
   Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $false
   ```

4. **Use proper CA-signed certificates** instead of self-signed

## OpenShift Security

### Service Account Permissions

Create dedicated service accounts with minimal permissions:

```bash
# Create service account
oc create sa compliance-automation -n compliance-test

# Grant only necessary permissions
oc adm policy add-role-to-user view -z compliance-automation -n compliance-test
oc adm policy add-role-to-user edit -z compliance-automation -n compliance-test
```

**Avoid** using cluster-admin unless absolutely necessary.

### Network Policies

Consider implementing NetworkPolicies to restrict traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: compliance-automation
spec:
  podSelector:
    matchLabels:
      app: compliance-scan
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: aap-controller
```

## Reporting Security

### Report Storage

Compliance reports may contain sensitive information:

- **Encrypt at rest:** Use encrypted PVCs or S3 buckets with encryption
- **Access control:** Limit who can view reports
- **Retention:** Delete old reports according to your retention policy

### Report Content

Reports may include:

- System configurations
- Security vulnerabilities (findings)
- Remediation details

Treat compliance reports as **confidential** security documentation.

## Checklist

Before deploying to production:

- [ ] All placeholder passwords (`CHANGE_ME_BEFORE_USE`) are replaced
- [ ] Vault files are encrypted
- [ ] `.gitignore` is properly configured
- [ ] No secrets in git history (use `git-secrets` or similar)
- [ ] WinRM using HTTPS with proper certificates
- [ ] Service accounts have minimal permissions
- [ ] Network policies restrict access appropriately
- [ ] Reports are stored securely
- [ ] Audit logging is enabled

## Scanning for Secrets

Before committing, scan for accidentally included secrets:

```bash
# Using git-secrets (https://github.com/awslabs/git-secrets)
git secrets --scan

# Using gitleaks (https://github.com/gitleaks/gitleaks)
gitleaks detect --source .

# Using trufflehog (https://github.com/trufflesecurity/trufflehog)
trufflehog git file://. --only-verified
```

## Reporting Security Issues

If you discover a security vulnerability in this collection, please:

1. **Do not** open a public GitHub issue
2. Contact the maintainers directly
3. Provide details of the vulnerability
4. Allow time for a fix before public disclosure
