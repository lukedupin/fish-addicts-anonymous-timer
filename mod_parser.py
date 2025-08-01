#!/usr/bin/env python3
import sys
import re
import os
from pathlib import Path

def parse_mod_content(content):
    """Parse the mod content and extract files based on comments."""
    
    files_to_write = {}
    current_file = None
    current_content = []
    
    lines = content.strip().split('\n')
    
    for line in lines:
        # Check if line is a comment indicating a file
        if line.strip().startswith('--') or line.strip().startswith('//'):
            # Remove comment markers and clean the line
            clean_line = re.sub(r'^[\s]*(-{2,}|/{2,})\s*', '', line).strip()
            
            # Check if this looks like a file path
            if ('.' in clean_line and 
                (clean_line.endswith('.lua') or 
                 clean_line.endswith('.json') or 
                 'locale' in clean_line.lower() or
                 clean_line.endswith('.cfg'))):
                
                # Save previous file if we have one
                if current_file and current_content:
                    files_to_write[current_file] = '\n'.join(current_content)
                
                # Start new file
                current_file = clean_line
                current_content = []
                continue
        
        # If we have a current file, add this line to its content
        if current_file:
            current_content.append(line)
    
    # Don't forget the last file
    if current_file and current_content:
        files_to_write[current_file] = '\n'.join(current_content)
    
    return files_to_write

def write_files(files_dict):
    """Write the extracted files to disk."""
    
    for filepath, content in files_dict.items():
        # Check if this is info.json and it already exists
        if filepath.lower().endswith('info.json') or 'info.json' in filepath.lower():
            if os.path.exists(filepath):
                print(f"Skipped: {filepath} (already exists - not overwriting)", file=sys.stderr)
                continue
        
        # Create directory structure if needed
        file_path = Path(filepath)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            # Clean up content - remove empty lines at start/end
            cleaned_content = content.strip()
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
            
            print(f"Written: {filepath}", file=sys.stderr)
            
        except Exception as e:
            print(f"Error writing {filepath}: {e}", file=sys.stderr)

def main():
    """Main function to read from file and process the mod content."""
    
    # Check if filename was provided as argument
    if len(sys.argv) != 2:
        print("Usage: python mod_parser.py <filename>", file=sys.stderr)
        print("Example: python mod_parser.py my_mod.txt", file=sys.stderr)
        return
    
    filename = sys.argv[1]
    
    # Check if file exists
    if not os.path.exists(filename):
        print(f"Error: File '{filename}' not found.", file=sys.stderr)
        return
    
    print(f"Mod File Parser - Reading from '{filename}'", file=sys.stderr)
    
    try:
        # Read content from file
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if not content.strip():
            print(f"Error: File '{filename}' is empty.", file=sys.stderr)
            return
        
        # Parse the content
        files = parse_mod_content(content)
        
        if not files:
            print("No files found in the input. Make sure your mod has comments indicating file paths.", file=sys.stderr)
            return
        
        print(f"Found {len(files)} files to extract:", file=sys.stderr)
        for filepath in files.keys():
            print(f"  - {filepath}", file=sys.stderr)
        
        # Write the files
        write_files(files)
        
        print("Extraction complete!", file=sys.stderr)
        
    except KeyboardInterrupt:
        print("\nOperation cancelled.", file=sys.stderr)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
