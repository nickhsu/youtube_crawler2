#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#define SIZE_VIDEO_ID 11

bool extract_video_id(char *data, char *video_id) {
	char *p = strstr(data, "video_id");
	if (p) {
		// 切出 video_id
		p += 13;

		strncpy(video_id, p, SIZE_VIDEO_ID);
		video_id[SIZE_VIDEO_ID] = '\0';
		return true;
	} else {
		return false;
	}
}

int main() {
	char buffer[BUFSIZ],
		 video_id[SIZE_VIDEO_ID + 1];

	while (fgets(buffer, BUFSIZ, stdin) != NULL) {
		if (extract_video_id(buffer, video_id)) {
			puts(video_id);
		}
	}
}
