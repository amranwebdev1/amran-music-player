#!/bin/bash

# ==========================================
# 🔄 স্মার্ট অটো-আপডেট সিস্টেম
# ==========================================
# ১. চেক করবে ইন্টারনেট কানেকশন আছে কি না
if ping -c 1 raw.githubusercontent.com &> /dev/null; then
    echo "🌐 Checking for updates..."
    
    # ২. নেটে কানেক্টেড থাকলে ব্যাকগ্রাউন্ডে শান্তভাবে লেটেস্ট ফাইল নামিয়ে ওভাররাইট করবে
    curl -sL https://raw.githubusercontent.com/amranwebdev1/amran-music-player/refs/heads/main/amp.sh -o $PREFIX/bin/amp
    chmod +x $PREFIX/bin/amp
fi

# ==========================================
# 🎵 আপনার আসল মিউজিক প্লেয়ারের কোড (নিচে থাকবে)
# ==========================================
clear
echo "Welcome to Amran Music Player!"
# ... আপনার বাকী প্লেয়ারের কোড এখানে থাকবে ...


echo -e "\033[1;32m⌛ Installing dependencies (mpv, fzf, figlet)...\033[0m"
pkg update -y && pkg install mpv fzf figlet -y

# Storage permission
termux-setup-storage

# add_favorite script
cat << 'FAV' > $PREFIX/bin/add_favorite
#!/bin/bash
files=("$@")
[ ${#files[@]} -eq 0 ] && exit 0
FAV_LIST="$HOME/.favorites.m3u"
touch "$FAV_LIST"
for item in "${files[@]}"; do
    clean_name=$(echo "$item" | sed 's/^[🎵⭐] //')
    real_file=$(grep -F "$clean_name" ~/.playlist.m3u | head -n 1)
    if [ -n "$real_file" ]; then
        if grep -q -F -x "$real_file" "$FAV_LIST"; then
            sed -i "\|$real_file|d" "$FAV_LIST"
        else
            echo "$real_file" >> "$FAV_LIST"
        fi
    fi
done
FAV
chmod +x $PREFIX/bin/add_favorite

# Main player script (Saved as 'amp')
cat << 'PLAY' > $PREFIX/bin/amp
#!/bin/bash
PLAYLIST="$HOME/.playlist.m3u"
FAV_LIST="$HOME/.favorites.m3u"
touch "$FAV_LIST"

find /sdcard/snaptube /sdcard/Download /sdcard/Music -type f \( -iname "*.mp3" -o -iname "*.m4a" \) 2>/dev/null > "$PLAYLIST"

CMD_ALL="while IFS= read -r line; do [ -n \"\$line\" ] && (grep -q -F -x \"\$line\" \"$FAV_LIST\" && echo \"⭐ \$(basename \"\$line\")\" || echo \"🎵 \$(basename \"\$line\")\"); done < \"$PLAYLIST\""
CMD_FAV="while IFS= read -r line; do [ -n \"\$line\" ] && echo \"⭐ \$(basename \"\$line\")\"; done < \"$FAV_LIST\""

HEADER="🎧 Amran Music Player  │ [ Ctrl+H: Help ]"

HELP_TEXT="📖 SHORTCUTS & CONTROLS HELP
─────────────────────────────────────────
🎵 MENU SHORTCUTS:
   Ctrl+A : View All Songs
   Ctrl+B : View Favorites List
   Ctrl+F : Toggle Favorite (Add/Remove)
   Ctrl+D : Delete Confirmation / Reload
   Ctrl+H : Toggle Help Window (Open / Close)

▶️ NOW PLAYING CONTROLS (mpv):
   Space / p : Pause / Resume
   n         : Next Song
   p         : Previous Song
   Up / Down : Volume (+5% / -5%)
   m         : Toggle Mute
   l         : Loop Single Song (ON/OFF)
   q         : Stop & Back to Menu"

while true; do
    clear

    # preview-window-এর রিজার্ভ স্পেস তুলে দিয়ে পুরো স্ক্রিন বক্স বড় করা হয়েছে
    selected=$(eval "$CMD_ALL" | fzf -m --height=100% --layout=reverse --wrap \
        --color="fg+:green,pointer:green,hl:yellow,marker:magenta:bold,header:cyan:bold,border:blue" \
        --border="rounded" \
        --header="$HEADER" \
        --preview="echo \"$HELP_TEXT\"" \
        --preview-window="down:50%:hidden:wrap" \
        --bind "ctrl-a:reload($CMD_ALL)" \
        --bind "ctrl-b:reload($CMD_FAV)" \
        --bind "ctrl-f:execute(add_favorite {+})+reload($CMD_ALL)" \
        --bind "ctrl-h:toggle-preview" \
        --bind "ctrl-d:execute(del_confirm {+})+reload(find /sdcard/snaptube /sdcard/Download /sdcard/Music -type f \( -iname '*.mp3' -o -iname '*.m4a' \) 2>/dev/null > ~/.playlist.m3u && $CMD_ALL)" | head -n 1)

    if [ -z "$selected" ]; then
        clear
        echo -e "\n\033[1;33m👋 Thank you for using Amran Music Player!\033[0m\n"
        break
    fi

    clean_name=$(echo "$selected" | sed 's/^[🎵⭐] //')
    selected_full=$(grep -F "$clean_name" "$PLAYLIST" | head -n 1)
    
    if [ -n "$selected_full" ]; then
        clear
        echo -e "\033[1;32m▶ Now Playing:\033[0m $clean_name"
        echo -e "\033[1;34m[ n = Next | p = Prev | Space = Pause | m = Mute | l = Loop | Up/Down = Vol | q = Back ]\033[0m\n"
        
        index=$(grep -n -F -x "$selected_full" "$PLAYLIST" | cut -d: -f1)
        
        mpv --playlist="$PLAYLIST" --playlist-start=$((index - 1)) \
            --input-conf=<(echo -e "n playlist-next\np playlist-prev\nUP add volume 5\nDOWN add volume -5\nm cycle mute\nl cycle-values loop-file \"inf\" \"no\"") \
            --term-osd-bar=yes \
            --term-osd-bar-chars="[██-]" \
            --term-status-msg=$'\033[1;32mProgress: ${time-pos} / ${duration} (${percent-pos}%)\033[0m'
    fi
done
PLAY
chmod +x $PREFIX/bin/amp

echo -e "\n\033[1;32m✅ Setup Complete! Run 'amp' to start.\033[0m\n"
