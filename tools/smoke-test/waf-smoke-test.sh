#!/bin/bash

# 🚀 Discover More: Testing Your Firewall in 60 Seconds: A Lightweight WAF Testing Script That Anyone Can Use
# Learn how this script works and the best practices for WAF testing.
# Read the full article here: 
# 👉 https://medium.com/@kochuraa/testing-your-firewall-in-60-seconds-a-lightweight-waf-testing-script-that-anyone-can-use-a7a725fefcb7

# Safe WAF Tester Script 
# Usage: ./waf-smoke-test.sh <URL> [-o output.md] [-H "Header: Value"]
# Examples:
#   Default testing: 
#     ./waf-smoke-test.sh "https://example.com"
#   Custom placeholder:
#     ./waf-smoke-test.sh "https://example.com/search?search=FUZZ"
#   With custom headers and output file:
#     ./waf-smoke-test.sh "https://example.com" -o results.md -H "User-Agent: Custom"

# Check dependencies
for cmd in curl awk sed grep; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# URL encode function (no Python dependency)
urlencode() {
  local string="$1"
  local strlen=${#string}
  local encoded=""
  local pos c o
  
  for ((pos=0; pos<strlen; pos++)); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9]) # Keep these characters unchanged
        o="$c" ;;
      *) # Encode everything else
        printf -v o '%%%02x' "'$c"
        ;;
    esac
    encoded+="$o"
  done
  echo "$encoded"
}

# Calculate percentage function
calc_percentage() {
    local numerator=$1
    local denominator=$2
    local decimals=${3:-1}
    
    if (( denominator == 0 )); then
        echo "0.0"
        return
    fi
    
    awk -v num="$numerator" -v den="$denominator" -v dec="$decimals" 'BEGIN {printf "%.*f", dec, (num/den)*100}'
}

# Check URL parameter
if [ $# -lt 1 ]; then
  echo "Error: URL parameter is required"
  echo "Usage: $0 <URL> [-o output.md] [-H \"Header: Value\"]"
  exit 1
fi

# Initialize variables
URL="$1"
OUTPUT_FILE=""
HEADERS=()

# Parse remaining arguments
shift
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      if [ $# -lt 2 ]; then
        echo "Error: -o requires an argument"
        exit 1
      fi
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -H)
      if [ $# -lt 2 ]; then
        echo "Error: -H requires an argument"
        exit 1
      fi
      HEADERS+=("-H" "$2")
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Attack payloads across multiple categories - using escaped versions for commands
PAYLOADS=(
    # SQL Injection
    "' OR '1'='1"
    "1; DROP TABLE waftest --"
    "admin' --"
    
    # XSS
    "<script>alert('xss')</script>"
    "<img src=x onerror=alert('xss')>"
    "<iframe src=\"javascript:alert('XSS')\"></iframe>"
    
    # Path Traversal
    "../../etc/passwd"
    "../../../../../../../etc/passwd"
    
    # Command Injection - ESCAPED to prevent shell execution
    "\$(cat /etc/passwd)"
    "| cat /etc/passwd"
    
    # SSRF
    "http://169.254.169.254/latest/meta-data/"
    "file:///etc/passwd"
    
    # NoSQL Injection
    "{'\\$gt':''}"
    "{\"\\$where\": \"this.password == this.passwordConfirm\"}"
    
    # Local File Inclusion
    "php://filter/convert.base64-encode/resource=index.php"
)

# Categories for each payload (prevents shell execution issues)
CATEGORIES=(
    "SQL Injection"
    "SQL Injection"
    "Other"
    
    "XSS"
    "XSS"
    "XSS"
    
    "Path Traversal"
    "Path Traversal"
    
    "Command Injection"
    "Command Injection"
    
    "SSRF"
    "SSRF"
    
    "NoSQL Injection"
    "NoSQL Injection"
    
    "LFI"
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Insert FUZZ placeholder if missing
if [[ ! "$URL" =~ FUZZ ]]; then
  if [[ "$URL" =~ \? ]]; then
    URL="${URL}&q=FUZZ"
  else
    URL="${URL}?q=FUZZ"
  fi
fi

printf "\n🔗 ${BLUE}Learn More:${NC} ${YELLOW}https://medium.com/@kochuraa/testing-your-firewall-in-60-seconds-a-lightweight-waf-testing-script-that-anyone-can-use-a7a725fefcb7${NC}\n"

printf "\n🔍 ${BLUE}WAF Smoke Test${NC}: ${YELLOW}%s${NC}\n" "$URL"
if [ ${#HEADERS[@]} -gt 0 ]; then
  printf "Headers: ${YELLOW}"
  for ((i=0; i<${#HEADERS[@]}; i+=2)); do
    printf "%s " "${HEADERS[i+1]}"
  done
  printf "${NC}\n"
fi
printf "\n%-3s %-40s %-12s %-10s %-20s\n" "#" "Payload" "Status" "HTTP Code" "Category"
printf "%s\n" "$(printf '%0.s-' $(seq 1 90))"

# Store results
results=()
i=1

# Initialize vulnerability flags
sql_vuln=0
xss_vuln=0
path_vuln=0
cmd_vuln=0
ssrf_vuln=0
nosql_vuln=0
lfi_vuln=0

# Using numeric indexing to avoid shell execution issues
for ((idx=0; idx<${#PAYLOADS[@]}; idx++)); do
    PAYLOAD="${PAYLOADS[$idx]}"
    CATEGORY="${CATEGORIES[$idx]}"
    
    # For display purposes - unescape $ for command injection payloads
    DISPLAY_PAYLOAD="${PAYLOAD//\\\$/\$}"
    DISPLAY_PAYLOAD="${DISPLAY_PAYLOAD//\\\"/\"}"
    
    # Encode and test the payload - use the original (escaped) payload for testing
    ENCODED_PAYLOAD=$(urlencode "$PAYLOAD")
    TARGET_URL=${URL//FUZZ/$ENCODED_PAYLOAD}
    
    # Use timeout for curl to avoid hanging
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${HEADERS[@]}" --connect-timeout 5 --max-time 10 "$TARGET_URL")

    # Evaluate the response
    if [[ "$RESPONSE" = "403" || "$RESPONSE" = "406" ]]; then
        STATUS="${GREEN}Blocked${NC}"
        STATUS_TEXT="Blocked"
    elif [[ "$RESPONSE" =~ ^(2|3) ]]; then
        STATUS="${RED}Allowed${NC}"
        STATUS_TEXT="Allowed"
        # Mark category as vulnerable if allowed
        if [ "$CATEGORY" = "SQL Injection" ]; then sql_vuln=1; fi
        if [ "$CATEGORY" = "XSS" ]; then xss_vuln=1; fi
        if [ "$CATEGORY" = "Path Traversal" ]; then path_vuln=1; fi
        if [ "$CATEGORY" = "Command Injection" ]; then cmd_vuln=1; fi
        if [ "$CATEGORY" = "SSRF" ]; then ssrf_vuln=1; fi
        if [ "$CATEGORY" = "NoSQL Injection" ]; then nosql_vuln=1; fi
        if [ "$CATEGORY" = "LFI" ]; then lfi_vuln=1; fi
    elif [[ "$RESPONSE" =~ ^5 ]]; then
        STATUS="${YELLOW}Error${NC}"
        STATUS_TEXT="Error"
    else:
        STATUS="${YELLOW}Check${NC}"
        STATUS_TEXT="Check"
    fi

    # Display result with safe truncation - properly formatted
    if [ ${#DISPLAY_PAYLOAD} -gt 37 ]; then
        DISPLAY_PAYLOAD="${DISPLAY_PAYLOAD:0:37}..."
    fi
    
    printf "%-3s %-40s %-12b %-10s %-20s\n" "$((i))" "$DISPLAY_PAYLOAD" "$STATUS" "$RESPONSE" "$CATEGORY"
    
    # Store the full untruncated payload for the report
    results+=("$DISPLAY_PAYLOAD,$STATUS_TEXT,$RESPONSE,$CATEGORY")
    ((i++))
done

# Calculate statistics
BLOCKED=0
ALLOWED=0
ERROR=0
CHECK=0

for result in "${results[@]}"; do
  IFS=',' read -r _ STATUS _ _ <<< "$result"
  if [ "$STATUS" = "Blocked" ]; then ((BLOCKED++)); fi
  if [ "$STATUS" = "Allowed" ]; then ((ALLOWED++)); fi
  if [ "$STATUS" = "Error" ]; then ((ERROR++)); fi
  if [ "$STATUS" = "Check" ]; then ((CHECK++)); fi
done

TOTAL=${#PAYLOADS[@]}

echo
printf "%s\n" "$(printf '%0.s-' $(seq 1 90))"
printf "\n📊 ${BLUE}Summary${NC}:\n"

# Calculate percentages
BLOCKED_PCT=$(calc_percentage $BLOCKED $TOTAL)
ALLOWED_PCT=$(calc_percentage $ALLOWED $TOTAL)
ERROR_PCT=$(calc_percentage $ERROR $TOTAL)
CHECK_PCT=$(calc_percentage $CHECK $TOTAL)

printf "  ${GREEN}Blocked${NC}: %d/%d (%.1f%%)\n" "$BLOCKED" "$TOTAL" "$BLOCKED_PCT"
printf "  ${RED}Allowed${NC}: %d/%d (%.1f%%)\n" "$ALLOWED" "$TOTAL" "$ALLOWED_PCT"
if [ $ERROR -gt 0 ]; then
  printf "  ${YELLOW}Error${NC}: %d/%d (%.1f%%)\n" "$ERROR" "$TOTAL" "$ERROR_PCT"
fi
if [ $CHECK -gt 0 ]; then
  printf "  ${YELLOW}Check${NC}: %d/%d (%.1f%%)\n" "$CHECK" "$TOTAL" "$CHECK_PCT"
fi

# Calculate security score
SCORE=$(calc_percentage $BLOCKED $TOTAL 0)
printf "\n🔒 ${BLUE}WAF Security Score${NC}: ${YELLOW}%d%%${NC}\n" "$SCORE"

# Protection rating
if [ "$SCORE" -ge 90 ]; then
    RATING="${GREEN}Excellent${NC}"
elif [ "$SCORE" -ge 70 ]; then
    RATING="${GREEN}Good${NC}"
elif [ "$SCORE" -ge 50 ]; then
    RATING="${YELLOW}Fair${NC}"
else
    RATING="${RED}Poor${NC}"
fi
printf "🔒 ${BLUE}Protection Rating${NC}: %b\n" "$RATING"

# WAF recommendations
echo -e "\n🔧 ${BLUE}WAF Recommendations${NC}:"

# Display recommendations for both AWS WAF and CloudFlare
if [ $sql_vuln -eq 1 ]; then
  echo -e "- ${RED}SQL Injection${NC}:"
  echo -e "  • ${GREEN}AWS WAF${NC}: Enable AWSManagedRulesSQLiRuleSet"
  echo -e "  • ${GREEN}CloudFlare${NC}: Enable OWASP Core Rule Set and SQLi Ruleset"
fi
if [ $xss_vuln -eq 1 ]; then
  echo -e "- ${RED}XSS${NC}:"
  echo -e "  • ${GREEN}AWS WAF${NC}: Enable AWSManagedRulesXSSRuleSet"
  echo -e "  • ${GREEN}CloudFlare${NC}: Enable Cross-site Scripting Attack Score"
fi
if [ $path_vuln -eq 1 ]; then
  echo -e "- ${RED}Path Traversal${NC}:"
  echo -e "  • ${GREEN}AWS WAF${NC}: Enable AWSManagedRulesKnownBadInputsRuleSet"
  echo -e "  • ${GREEN}CloudFlare${NC}: Enable Directory Traversal Attack Protection"
fi
if [ $cmd_vuln -eq 1 ]; then
  echo -e "- ${RED}Command Injection${NC}:"
  echo -e "  • ${GREEN}AWS WAF${NC}: Enable AWSManagedRulesLinuxRuleSet"
  echo -e "  • ${GREEN}CloudFlare${NC}: Enable Server-Side Code Injection Attack Protection"
fi
if [ $ssrf_vuln -eq 1 ]; then
  echo -e "- ${RED}SSRF${NC}:"
  echo -e "  • ${GREEN}AWS WAF${NC}: Configure custom WAF rules for SSRF protection"
  echo -e "  • ${GREEN}CloudFlare${NC}: Create custom rule to block cloud metadata endpoints"
fi
if [ $nosql_vuln -eq 1 ] || [ $lfi_vuln -eq 1 ]; then
  echo -e "- ${RED}Advanced Threats${NC}:"
  echo -e "  • ${GREEN}AWS WAF${NC}: Enable AWSManagedRulesCommonRuleSet"
  echo -e "  • ${GREEN}CloudFlare${NC}: Enable High and Medium Risk Level Rules"
fi

# Generate markdown report if requested - using echo instead of printf for bullet points
if [ -n "$OUTPUT_FILE" ]; then
  # Create the file and clear it
  > "$OUTPUT_FILE"
  
  # Add content using echo with >> to append
  echo "# WAF Security Test Report" >> "$OUTPUT_FILE"
  echo "Date: $(date)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  echo "## Test Configuration" >> "$OUTPUT_FILE"
  echo "- URL: $URL" >> "$OUTPUT_FILE"
  if [ ${#HEADERS[@]} -gt 0 ]; then
    echo -n "- Headers: " >> "$OUTPUT_FILE"
    for ((i=0; i<${#HEADERS[@]}; i+=2)); do
      echo -n "${HEADERS[i+1]} " >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  else
    echo "- Headers: None" >> "$OUTPUT_FILE"
  fi
  echo "" >> "$OUTPUT_FILE"
  
  echo "## Summary" >> "$OUTPUT_FILE"
  echo "- Total Tests: $TOTAL" >> "$OUTPUT_FILE"
  echo "- Blocked: $BLOCKED (${BLOCKED_PCT}%)" >> "$OUTPUT_FILE"
  echo "- Allowed: $ALLOWED (${ALLOWED_PCT}%)" >> "$OUTPUT_FILE"
  if [ $ERROR -gt 0 ]; then
    echo "- Error: $ERROR (${ERROR_PCT}%)" >> "$OUTPUT_FILE"
  fi
  if [ $CHECK -gt 0 ]; then
    echo "- Check: $CHECK (${CHECK_PCT}%)" >> "$OUTPUT_FILE"
  fi
  echo "- Security Score: $SCORE%" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  echo "## Results by Category" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # List of categories to check
  categories=("SQL Injection" "XSS" "Path Traversal" "Command Injection" "SSRF" "NoSQL Injection" "LFI" "Other")
  
  # Print results grouped by category
  for cat in "${categories[@]}"; do
    # Skip categories with no results
    cat_exists=0
    for result in "${results[@]}"; do
      if [[ "$result" == *",$cat" ]]; then
        cat_exists=1
        break
      fi
    done
    
    if [ $cat_exists -eq 1 ]; then
      echo "### $cat" >> "$OUTPUT_FILE"
      echo "" >> "$OUTPUT_FILE"
      echo "| # | Payload | Status | HTTP Code |" >> "$OUTPUT_FILE"
      echo "|---|---------|--------|-----------|" >> "$OUTPUT_FILE"
      
      cat_idx=1
      for result in "${results[@]}"; do
        IFS=',' read -r PAYLOAD STATUS CODE CATEGORY <<< "$result"
        if [ "$CATEGORY" = "$cat" ]; then
          # Escape pipe characters for markdown table
          PAYLOAD="${PAYLOAD//|/\\|}"
          
          echo "| $cat_idx | $PAYLOAD | $STATUS | $CODE |" >> "$OUTPUT_FILE"
          ((cat_idx++))
        fi
      done
      echo "" >> "$OUTPUT_FILE"
    fi
  done
  
  echo "## WAF Recommendations" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  if [ $sql_vuln -eq 1 ]; then
    echo "### SQL Injection" >> "$OUTPUT_FILE"
    echo "* AWS WAF: Enable AWSManagedRulesSQLiRuleSet" >> "$OUTPUT_FILE"
    echo "* CloudFlare: Enable OWASP Core Rule Set and SQLi Ruleset" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
  if [ $xss_vuln -eq 1 ]; then
    echo "### XSS" >> "$OUTPUT_FILE"
    echo "* AWS WAF: Enable AWSManagedRulesXSSRuleSet" >> "$OUTPUT_FILE"
    echo "* CloudFlare: Enable Cross-site Scripting Attack Score" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
  if [ $path_vuln -eq 1 ]; then
    echo "### Path Traversal" >> "$OUTPUT_FILE"
    echo "* AWS WAF: Enable AWSManagedRulesKnownBadInputsRuleSet" >> "$OUTPUT_FILE"
    echo "* CloudFlare: Enable Directory Traversal Attack Protection" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
  if [ $cmd_vuln -eq 1 ]; then
    echo "### Command Injection" >> "$OUTPUT_FILE"
    echo "* AWS WAF: Enable AWSManagedRulesLinuxRuleSet" >> "$OUTPUT_FILE"
    echo "* CloudFlare: Enable Server-Side Code Injection Attack Protection" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
  if [ $ssrf_vuln -eq 1 ]; then
    echo "### SSRF" >> "$OUTPUT_FILE"
    echo "* AWS WAF: Configure custom WAF rules for SSRF protection" >> "$OUTPUT_FILE"
    echo "* CloudFlare: Create custom rule to block cloud metadata endpoints" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
  if [ $nosql_vuln -eq 1 ] || [ $lfi_vuln -eq 1 ]; then
    echo "### Advanced Threats" >> "$OUTPUT_FILE"
    echo "* AWS WAF: Enable AWSManagedRulesCommonRuleSet" >> "$OUTPUT_FILE"
    echo "* CloudFlare: Enable High and Medium Risk Level Rules" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi
  
  echo -e "\n📄 Report saved to ${YELLOW}$OUTPUT_FILE${NC}"
fi

echo -e "\n📅 Test Date: $(date)"
echo
