#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <assert.h>

#define SIZE_YOUTUBE_ID 11
#define BUFSIZ 1024 * 16

/*
 * hash table
 * */
typedef struct {
	char id[SIZE_YOUTUBE_ID + 1];
} YoutubeID;

typedef struct {
	size_t count;
	size_t size;
	YoutubeID *data;
} HashTable;

HashTable *hash_table_new(size_t size) {
	HashTable *t;

	t = malloc(sizeof(HashTable));
	t->count = 0;
	t->size = size;
	t->data = malloc(sizeof(YoutubeID) * size);
	memset(t->data, '\0', sizeof(YoutubeID) * size);

	return t;
}

size_t hash_table_hash_function(HashTable *t, YoutubeID *youtube_id) {
	size_t i = 0,
		   hash_value = 0;

	for (i = 0; i < SIZE_YOUTUBE_ID; i++) {
		hash_value = (hash_value + youtube_id->id[i]) << 5;
	}
	
	return hash_value % t->size;
}

void hash_table_insert(HashTable *t, YoutubeID *youtube_id) {
	size_t hash_value = hash_table_hash_function(t, youtube_id);
	YoutubeID *p;
	
	printf("hash_val = %zd\n", hash_value);
	for (p = &t->data[hash_value]; p->id[0] != '\0'; p++)
		;
	memcpy(p, youtube_id, sizeof(YoutubeID));
	t->count++;

	return;
}

void hash_table_free(HashTable *t) {
	free(t->data);
	t->data = NULL;
}

bool hash_table_find(HashTable *t, YoutubeID *youtube_id) {
	size_t hash_value = hash_table_hash_function(t, youtube_id);
	YoutubeID *p;

	for (p = &t->data[hash_value]; p->id[0] != '\0'; p++) {
		if (memcmp(p, youtube_id, sizeof(YoutubeID)) == 0) {
			return true;
		}
	}

	return false;
}

bool hash_table_is_fulled(HashTable *t) {
	return t->count >= t->size;
}

void hash_table_print_stat(HashTable *t) {
	int i,
		cluster_counter = 0;

	/*
	cluster_counter = 0;
	for (i = 0; i < t->size; i++) {
		if (t->data[i].id[0] != '\0') {
			cluster_counter++;
		} else {
			if (cluster_counter != 0) {
				printf("cluster_counter = %d\n", cluster_counter);
				cluster_counter = 0;
			}
		}
	}
	*/
	for (i = 0; i < t->size; i++) {
		if (t->data[i].id[0] != '\0') {
			printf("%s\n", t->data[i].id);
		} else {
			printf("--\n");
		}
	}
}

void hash_table_test() {
	HashTable *hash_table = NULL;
	YoutubeID test_id_1 = {"I90Rwik2w7I"},
			  test_id_2 = {"I90Rwik2w7H"},
			  test_id_3 = {"I90Rwik2w7A"},
			  test_id_4 = {"I90Rwik2w7Y"};

	// test hash_table_new()
	printf("test hash_table_new()\n");
	hash_table = hash_table_new(100);

	assert(hash_table->count == 0);
	assert(hash_table->size == 100);
	assert(hash_table->data != NULL);

	// test hash_table_insert()
	printf("test hash_table_insert()\n");
	hash_table_insert(hash_table, &test_id_1);
	hash_table_insert(hash_table, &test_id_2);
	hash_table_insert(hash_table, &test_id_3);

	assert(hash_table->count == 3);

	// test hash_table_find()
	printf("test hash_table_find()\n");
	assert(hash_table_find(hash_table, &test_id_1) == true);
	assert(hash_table_find(hash_table, &test_id_2) == true);
	assert(hash_table_find(hash_table, &test_id_3) == true);
	assert(hash_table_find(hash_table, &test_id_4) == false);

	// test hash_table_free()
	printf("test hash_table_free()\n");
	hash_table_free(hash_table);

	assert(hash_table->data == NULL);
}

/*
 * option handler functions
 * */

typedef struct {
	char id_list_path[100];
	size_t size_hash_table;
} Option;

Option *option_new(int argc, char *const argv[]) {
	int c;
	Option *option = malloc(sizeof(Option));

	strcpy(option->id_list_path, "");
	option->size_hash_table = 0;

	while ((c = getopt(argc, argv, "f:n:")) != -1) {
		switch(c) {
		case 'f':
			strcpy(option->id_list_path, optarg);
			break;
		case 'n':
			option->size_hash_table = atoi(optarg);
			break;
		}
	}

	return option;
}

void printf_help_info() {
	printf("Usage: mem_uniq -f id_list_path -n hash_table_size\n");
}

/*
 * other function
 * */

bool extract_video_id(char *data, char *video_id) {
	char *p = strstr(data, "video_id");
	if (p) {
		// 切出 video_id
		p += 13;

		strncpy(video_id, p, SIZE_YOUTUBE_ID);
		return true;
	} else {
		return false;
	}
}

/* 
 * main code
 * */
int main(int argc, char *argv[]) {
	Option *option;
	FILE *fp;
	char buffer[BUFSIZ];
	HashTable *hash_table = NULL;
	YoutubeID youtube_id;

	/* parse option */
	option = option_new(argc, argv);
	if (strcmp(option->id_list_path, "") == 0|| option->size_hash_table == 0) {
		printf_help_info();
		exit(0);
	}

	/* open id list file */
	fp = fopen(option->id_list_path, "a+");
	if (fp == NULL) {
		printf("open id list file '%s' fail\n", option->id_list_path);
		exit(0);
	}

	/* create hash table */
	hash_table = hash_table_new(option->size_hash_table);
	fseek(fp, 0, SEEK_SET);
	while (fgets(buffer, BUFSIZ, fp) != NULL) {
		buffer[strlen(buffer) - 1] = '\0'; // delete '\n'
		hash_table_insert(hash_table, (YoutubeID*) buffer);
	}
	fseek(fp, 0, SEEK_END);

	fprintf(stderr, "INFO: hash_table->size  = %zd\n", hash_table->size);
	fprintf(stderr, "INFO: hash_table->count = %zd\n", hash_table->count);
	hash_table_print_stat(hash_table);

	/* filte input */
	/*
	while (fgets(buffer, BUFSIZ, stdin) != NULL) {
		if (extract_video_id(buffer, (char*) &youtube_id)) {
			if (!hash_table_find(hash_table, &youtube_id)) {
				fputs(buffer, stdout);
				hash_table_insert(hash_table, &youtube_id);
				fprintf(fp, "%s\n", youtube_id.id);

				if (hash_table_is_fulled(hash_table)) {
					fprintf(stderr, "ERROR: the hash table is full!\n");
					fprintf(stderr, "hash table size: %zd\n", hash_table->size);
					exit(0);
				}
			}
		}
	}
	*/
	fclose(fp);
	hash_table_free(hash_table);

	return 0;
}
