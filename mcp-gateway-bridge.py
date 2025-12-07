#!/usr/bin/env python3
"""
Bridge script that invokes Docker MCP Gateway with stdio transport.
This script runs docker mcp gateway run as a subprocess and forwards stdio.
"""
import sys
import subprocess
import os

def main():
    try:
        # Use the default Docker context (via mounted socket)
        # Don't set DOCKER_CONTEXT as it won't work inside the container
        env = os.environ.copy()
        
        # Run docker mcp gateway with stdio transport (default)
        # This will communicate via stdin/stdout
        process = subprocess.Popen(
            ['/usr/bin/docker', 'mcp', 'gateway', 'run'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            env=env
        )
        
        # Forward stdin to process
        import threading
        def forward_stdin():
            try:
                while True:
                    data = sys.stdin.buffer.read(4096)
                    if not data:
                        break
                    process.stdin.write(data)
                    process.stdin.flush()
            except:
                pass
            finally:
                process.stdin.close()
        
        stdin_thread = threading.Thread(target=forward_stdin, daemon=True)
        stdin_thread.start()
        
        # Forward process stdout to stdout
        while True:
            data = process.stdout.read(4096)
            if not data:
                break
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
        
        process.wait()
        sys.exit(process.returncode)
        
    except Exception as e:
        print(f"Bridge error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
