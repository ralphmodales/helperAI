import os
import sys
from dotenv import load_dotenv
from exa_py import Exa
import argparse


def load_exa_client():
    load_dotenv()
    api_key = os.getenv("EXA_API_KEY")
    if not api_key:
        print("Error: EXA_API_KEY not found.")
        sys.exit(1)
    return Exa(api_key=api_key)


def get_description(content):
    return (content or "")[:200] + ("..." if len(content or "") > 200 else "")


def search(client, query):
    try:
        results = client.search_and_contents(query, text={"max_characters": 2000})
        if not results.results:
            return ["No results found."]

        ranked = sorted(
            results.results,
            key=lambda r: len(r.text or r.content or "")
            * sum(
                word in (r.text or r.content or "").lower()
                for word in query.lower().split()
            ),
            reverse=True,
        )
        top_5 = ranked[:5]

        output = [f"Top 5 Results for: '{query}'", ""]

        for i, result in enumerate(top_5, 1):
            content = result.text or result.content or ""
            desc = get_description(content)
            output.append(f"{i}. {result.title}")
            output.append(f"   Description: {desc}")
            output.append(f"   URL: {result.url}")
            output.append(
                f"   Content: {content[:500]}{'...' if len(content) > 500 else ''}"
            )
            output.append("")

        return output

    except Exception as e:
        return [f"Error occurred: {str(e)}"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", required=True, help="Search query")
    args = parser.parse_args()

    client = load_exa_client()
    results = search(client, args.query)

    for line in results:
        print(line, flush=True)


if __name__ == "__main__":
    main()
