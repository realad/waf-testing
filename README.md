# WAF Testing

A lightweight toolkit for testing Web Application Firewall (WAF) effectiveness and identifying security gaps. This repository is available as a template that you can quickly customize for your own WAF testing needs.

## Overview

WAF Testing provides a set of tools to verify that your Web Application Firewall is actually blocking common attacks, not just appearing to be configured correctly. The toolkit's flagship component is a fast WAF smoke test script that can evaluate your WAF's effectiveness in seconds.

## Key Features

- **Quick Smoke Testing**: Test your WAF against 15+ attack vectors in under 60 seconds
- **Cross-Platform**: Works on Linux, macOS, and Windows (via Git Bash)
- **Cloud WAF Support**: Includes specific recommendations for AWS WAF and CloudFlare
- **Comprehensive Coverage**: Tests SQL injection, XSS, path traversal, SSRF, and more
- **Human-Readable Reports**: Generates clear Markdown reports with actionable recommendations
- **CI/CD Integration**: Pre-configured GitHub Actions workflow for automated testing

## Using This Template

This repository is configured as a GitHub template, making it easy to get started:

1. Click the "Use this template" button at the top of the repository
2. Name your new repository and click "Create repository from template"
3. Clone your new repository to your local machine
4. Set up your GitHub repository secret for `WAF_TEST_URL` (the URL you want to test)
5. Run the workflow manually through GitHub Actions or wait for the scheduled run

### Setting Up the Secret

For the GitHub Actions workflow to run properly:

1. Go to your repository's Settings tab
2. Navigate to Secrets and variables > Actions
3. Click "New repository secret"
4. Name: `WAF_TEST_URL`
5. Value: The URL of the website/API you want to test (e.g., `https://your-website.com`)

## Getting Started Locally

### Prerequisites

- Bash shell environment
- curl
- awk
- grep
- sed

### Basic Usage

```bash
# Run a basic test against a URL
./tools/smoke-test/waf-smoke-test.sh "https://your-website.com"

# Test with custom HTTP headers
./tools/smoke-test/waf-smoke-test.sh "https://your-website.com" -H "User-Agent: Custom Browser"

# Generate a Markdown report
./tools/smoke-test/waf-smoke-test.sh "https://your-website.com" -o waf-report.md
```

### Custom Test Placement

By default, the script adds a `?q=FUZZ` parameter to your URL. If you want to test a specific parameter, use the `FUZZ` placeholder in your URL:

```bash
./tools/smoke-test/waf-smoke-test.sh "https://your-website.com/search?term=FUZZ"
```

## Understanding Results

The script produces a security score ranging from 0% to 100% based on how many attack vectors your WAF blocks. The rating scale is:

- **Excellent**: 90-100%
- **Good**: 70-89%
- **Fair**: 50-69%
- **Poor**: 0-49%

Results also include specific AWS WAF and CloudFlare rule recommendations based on the detected vulnerabilities.

## Included CI/CD Integration

This template includes a pre-configured GitHub Actions workflow (`.github/workflows/smoke-test.yml`) that:

1. Runs automatically every Monday at midnight
2. Can be triggered manually through the Actions tab
3. Tests your WAF on macOS, Ubuntu, and Windows
4. Uses the URL specified in your `WAF_TEST_URL` secret

To customize the schedule, edit the cron expression in the workflow file.

## Platform Compatibility

### Linux
Works out of the box on most distributions.

### macOS
Works out of the box.

### Windows
Requires Git Bash or Windows Subsystem for Linux (WSL).

For Git Bash users, ensure you have awk, grep, and sed installed:
```bash
# Install dependencies via pacman in Git Bash
pacman -S awk grep sed
```

## Security Considerations

The test payloads are designed to test WAF functionality without causing harm. However, use caution when testing production systems and consider:

1. Testing in staging environments first
2. Running tests during low-traffic periods
3. Informing your security team before testing

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Further Reading

For more information on WAF testing best practices, read my article: [Testing Your Firewall in 60 Seconds: A Lightweight WAF Testing Script That Anyone Can Use](https://medium.com/@kochuraa/testing-your-firewall-in-60-seconds-a-lightweight-waf-testing-script-that-anyone-can-use-a7a725fefcb7)

---

⭐ If this project helped you, please consider giving it a star!
