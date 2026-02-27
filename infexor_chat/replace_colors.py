import os

files_primary = [
    r"e:\Whatapplikeapp\infexor_chat\lib\features\home\home_screen.dart",
    r"e:\Whatapplikeapp\infexor_chat\lib\features\chat\widgets\chat_background.dart",
    r"e:\Whatapplikeapp\infexor_chat\lib\features\chat\screens\chat_list_screen.dart",
    r"e:\Whatapplikeapp\infexor_chat\lib\features\chat\screens\conversation_screen.dart",
    r"e:\Whatapplikeapp\infexor_chat\lib\features\chat\screens\calls_screen.dart",
    r"e:\Whatapplikeapp\infexor_chat\lib\features\auth\screens\login_screen.dart",
    r"e:\Whatapplikeapp\infexor_chat\lib\core\constants\app_colors.dart"
]

for f in files_primary:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content.replace("0xFFFF6D00", "0xFFFF6B6B").replace("0xFFFF8A65", "0xFFFFA07A"))
