import os
import sys
import requests

def main(directory):
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        print("Error: OPENAI_API_KEY environment variable not set.")
        sys.exit(1)

    # Gather all files' content
    content = ""
    for root, dirs, files in os.walk(directory):
        for filename in files:
            filepath = os.path.join(root, filename)
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                file_content = f.read()
                content += f"\n\n--- {filename} ---\n"
                content += file_content

    # Prepare prompt for GPT
    prompt = (
        "Review the following code files and provide a summary with any suggestions:\n"
        f"{content}"
    )

    # Call OpenAI API
    response = requests.post(
        "https://api.openai.com/v1/completions",
        headers={
            "Authorization": f"Bearer {api_key}"
        },
        json={
            "model": "text-davinci-003",
            "prompt": prompt,
            "max_tokens": 1500,
            "temperature": 0.2,
            "n": 1,
            "stop": None
        }
    )

    if response.status_code != 200:
        print("Error:", response.text)
        sys.exit(1)

    result = response.json()
    print("=== Review Summary from OpenAI ===")
    print(result['choices'][0]['text'])

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python scripts/send_openai.py <directory>")
        sys.exit(1)

    main(sys.argv[1])