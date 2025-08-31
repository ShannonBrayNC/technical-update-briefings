# scripts/send_review.py
import sys
import os
import requests

def main(directory):
    files = []
    for root, dirs, filenames in os.walk(directory):
        for filename in filenames:
            filepath = os.path.join(root, filename)
            with open(filepath, 'rb') as f:
                files.append(('file', (filename, f.read())))
    # Send to your API endpoint
    response = requests.post(
        "https://your-review-api.com/analyze",
        headers={"Authorization": f"Bearer {os.environ['API_KEY']}"},
        files=files
    )
    print(response.text)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: send_review.py <directory>")
        sys.exit(1)
    main(sys.argv[1])