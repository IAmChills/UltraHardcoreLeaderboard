![Logo](https://media.forgecdn.net/avatars/thumbnails/1461/177/64/64/638948383876436269.png "Logo")
# Ultra Hardcore Live Leaderboard

Ultra Hardcore Live Leaderboard is a companion addon to the World of Warcraft Classic addon Ultra Hardcore.

## Notes

*Due to World of Warcraft Classic limitations, the leaderboard will only show other Ultra Hardcore players within your Guild.*

## Features and Logic

- Basic player information is shown to include their Ultra Hardcore stats and Preset.
  - **Name**: Players name
  - **Level**: Players current level
  - **Class**: Players class
  - **Preset**: Lite, Recommended, Experimental (Ultra), Custom
  - **Seen**: Time since last update (eg. 5m)
  - **Version**: The version of Ultra Hardcore being used
  - **Stats**: Lowest health, elites slain, enemies slain, XP gained without addon
![Leaderbaord](https://media.forgecdn.net/attachments/1343/760/leaderboard-png.png "Leaderboard")
- Right click for context menu (whisper, invite)
- A minimap button
- A tooltip is displayed for each player to detail which options are currently enabled

![Tooltip](https://media.forgecdn.net/attachments/1342/639/tooltip-png.png "Tooltip")
- Table is ordered by online status, level, then player name (dynamic sorting to be added)
- Player information is sent on login, reload, level up, death, logout and every 60 seconds
- Players are removed from the leaderboard after 7 days of inactivity
- The leaderboard is automatically refreshed if left open
