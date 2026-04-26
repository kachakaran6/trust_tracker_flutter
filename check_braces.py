import sys

def check_braces(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    stack = []
    for i, char in enumerate(content):
        if char == '{':
            stack.append(i)
        elif char == '}':
            if not stack:
                print(f"Extra closing brace at index {i}")
            else:
                stack.pop()
    
    if stack:
        for pos in stack:
            line = content.count('\n', 0, pos) + 1
            print(f"Unmatched opening brace at line {line}")

if __name__ == "__main__":
    check_braces(sys.argv[1])
