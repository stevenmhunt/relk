#!/usr/bin/env bash

TARGET="./dist/relk"

build_relk_shell_script() {
    while IFS="" read -r file || [ -n "$file" ]
    do
        echo ""
        cat "./src/${file}"
    done < "./src/sources.txt"
}

mkdir -p "./dist"

echo "#!/usr/bin/env bash
# Relk - Relational Key Store
# Licensed under MIT License

RELK_SHARED=/usr/local/share/relk" > "$TARGET"

build_relk_shell_script >> "$TARGET"
echo "" >> "$TARGET"
echo "relk_main \"\$@\"" >> "$TARGET"
chmod +x "$TARGET"