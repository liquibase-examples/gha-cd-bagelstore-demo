#!/usr/bin/env python3
"""
Harness API Search Utility

Quickly search the downloaded OpenAPI spec for endpoints, examples, and schemas.

Usage:
    ./scripts/search-harness-api.py "pipeline execute"
    ./scripts/search-harness-api.py "pipeline execute" --show-example
    ./scripts/search-harness-api.py --endpoint "/pipeline/api/pipeline/execute/{identifier}"
    ./scripts/search-harness-api.py --list-all
"""

import json
import sys
import argparse
from pathlib import Path


def load_openapi_spec():
    """Load the Harness OpenAPI spec from docs/harness-openapi-formatted.json"""
    spec_path = Path(__file__).parent.parent / "docs" / "harness-openapi-formatted.json"

    if not spec_path.exists():
        print(f"Error: OpenAPI spec not found at {spec_path}", file=sys.stderr)
        print("Run this to download it:", file=sys.stderr)
        print("  curl -s 'https://apidocs.harness.io/page-data/shared/oas-index.yaml.json' -o docs/harness-openapi.json", file=sys.stderr)
        sys.exit(1)

    with open(spec_path, 'r') as f:
        data = json.load(f)

    return data['definition']


def search_paths(spec, query):
    """Search for paths matching the query"""
    query_terms = [term.lower() for term in query.split()]
    matches = []

    for path, methods in spec['paths'].items():
        path_lower = path.lower()

        # Get method details for searching
        search_text = path_lower
        for method, details in methods.items():
            if method in ['get', 'post', 'put', 'delete', 'patch']:
                summary = details.get('summary', '').lower()
                description = details.get('description', '').lower()
                operation_id = details.get('operationId', '').lower()
                search_text += ' ' + summary + ' ' + description + ' ' + operation_id

        # Check if all query terms are present
        if all(term in search_text for term in query_terms):
            matches.append((path, methods, 'matched'))

    return matches


def format_endpoint_info(path, methods, show_example=False):
    """Format endpoint information for display"""
    output = []
    output.append(f"\n{'='*80}")
    output.append(f"ENDPOINT: {path}")
    output.append(f"{'='*80}\n")

    for method, details in methods.items():
        if method not in ['get', 'post', 'put', 'delete', 'patch']:
            continue

        output.append(f"Method: {method.upper()}")
        output.append(f"Summary: {details.get('summary', 'N/A')}")

        if 'operationId' in details:
            output.append(f"Operation ID: {details['operationId']}")

        # Query parameters
        if 'parameters' in details:
            output.append("\nQuery Parameters:")
            for param in details['parameters']:
                required = " (required)" if param.get('required') else ""
                output.append(f"  - {param.get('name')}{required}: {param.get('description', 'N/A')[:100]}")

        # Request body
        if 'requestBody' in details:
            output.append("\nRequest Body:")
            req_body = details['requestBody']
            output.append(f"  Description: {req_body.get('description', 'N/A')[:200]}")

            content = req_body.get('content', {})
            for content_type in content.keys():
                output.append(f"  Content-Type: {content_type}")

            # Show example if requested
            if show_example:
                for content_type, schema_info in content.items():
                    if 'examples' in schema_info:
                        output.append(f"\n  Example ({content_type}):")
                        for example_name, example_data in schema_info['examples'].items():
                            output.append(f"    {example_name}:")
                            value = example_data.get('value', '')
                            if isinstance(value, str):
                                # Truncate long examples
                                lines = value.split('\n')
                                if len(lines) > 20:
                                    output.append("      " + "\n      ".join(lines[:20]))
                                    output.append(f"      ... ({len(lines) - 20} more lines)")
                                else:
                                    output.append("      " + "\n      ".join(lines))
                            else:
                                output.append(f"      {json.dumps(value, indent=2)[:500]}")

        # Responses
        if 'responses' in details:
            output.append("\nResponses:")
            for code, resp in details['responses'].items():
                output.append(f"  {code}: {resp.get('description', 'N/A')}")

        output.append("")

    return "\n".join(output)


def list_all_endpoints(spec):
    """List all available endpoints"""
    endpoints = []

    for path, methods in spec['paths'].items():
        available_methods = [m.upper() for m in methods.keys() if m in ['get', 'post', 'put', 'delete', 'patch']]
        summary = ""

        for method, details in methods.items():
            if method in ['get', 'post', 'put', 'delete', 'patch']:
                summary = details.get('summary', '')
                break

        endpoints.append({
            'path': path,
            'methods': ', '.join(available_methods),
            'summary': summary[:60] + '...' if len(summary) > 60 else summary
        })

    # Sort by path
    endpoints.sort(key=lambda x: x['path'])

    print(f"\nTotal endpoints: {len(endpoints)}\n")
    print(f"{'Path':<60} {'Methods':<15} {'Summary'}")
    print(f"{'-'*60} {'-'*15} {'-'*60}")

    for ep in endpoints:
        print(f"{ep['path']:<60} {ep['methods']:<15} {ep['summary']}")


def main():
    parser = argparse.ArgumentParser(
        description='Search Harness OpenAPI spec',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Search for pipeline execute endpoints
  %(prog)s "pipeline execute"

  # Show example request/response
  %(prog)s "pipeline execute" --show-example

  # Get details for specific endpoint
  %(prog)s --endpoint "/pipeline/api/pipeline/execute/{identifier}"

  # List all available endpoints
  %(prog)s --list-all

  # Search with multiple terms (AND)
  %(prog)s "pipeline" --filter "execute"
        """
    )

    parser.add_argument('query', nargs='?', help='Search query (searches paths, summaries, descriptions)')
    parser.add_argument('--endpoint', help='Get details for specific endpoint path')
    parser.add_argument('--show-example', action='store_true', help='Show request/response examples')
    parser.add_argument('--list-all', action='store_true', help='List all available endpoints')
    parser.add_argument('--filter', help='Additional filter term (AND with query)')
    parser.add_argument('--limit', type=int, default=10, help='Limit number of results (default: 10)')

    args = parser.parse_args()

    # Load spec
    spec = load_openapi_spec()

    # List all endpoints
    if args.list_all:
        list_all_endpoints(spec)
        return

    # Get specific endpoint
    if args.endpoint:
        if args.endpoint in spec['paths']:
            print(format_endpoint_info(args.endpoint, spec['paths'][args.endpoint], args.show_example))
        else:
            print(f"Error: Endpoint '{args.endpoint}' not found", file=sys.stderr)
            print("\nDid you mean one of these?", file=sys.stderr)
            similar = [p for p in spec['paths'].keys() if args.endpoint.lower() in p.lower()]
            for path in similar[:5]:
                print(f"  {path}", file=sys.stderr)
            sys.exit(1)
        return

    # Search query required
    if not args.query:
        parser.print_help()
        sys.exit(1)

    # Search
    matches = search_paths(spec, args.query)

    # Apply additional filter
    if args.filter:
        filter_lower = args.filter.lower()
        matches = [m for m in matches if filter_lower in m[0].lower() or filter_lower in str(m[1]).lower()]

    if not matches:
        print(f"No endpoints found matching: {args.query}")
        if args.filter:
            print(f"  with filter: {args.filter}")
        sys.exit(0)

    # Show results
    print(f"\nFound {len(matches)} endpoint(s) matching '{args.query}'")
    if args.filter:
        print(f"  with filter '{args.filter}'")
    print()

    for i, (path, methods, match_type) in enumerate(matches[:args.limit]):
        if i > 0:
            print("\n" + "="*80 + "\n")
        print(format_endpoint_info(path, methods, args.show_example))

    if len(matches) > args.limit:
        print(f"\n... and {len(matches) - args.limit} more results (use --limit to see more)")


if __name__ == '__main__':
    main()
