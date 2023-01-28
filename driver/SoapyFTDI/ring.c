#include <stdlib.h>
#include <stddef.h>
#include <stdio.h>
#include <stdbool.h>
#include <pthread.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include <unistd.h>

#define BLOCK_SIZE 1024
#define BUFFER_SIZE 128

bool enabled = 1;

typedef struct circular_buffer
{
    void *buffer;     // data buffer
    void *buffer_end; // end of data buffer
    size_t capacity;  // maximum number of items in the buffer
    size_t count;     // number of items in the buffer
    size_t sz;        // size of each item in the buffer
    void *head;       // pointer to head
    void *tail;       // pointer to tail
} circular_buffer;

circular_buffer cb;

void cb_init(circular_buffer *cb, size_t capacity, size_t sz)
{
    cb->buffer = malloc(capacity * sz);
    cb->buffer_end = (char *)cb->buffer + capacity * sz;
    cb->capacity = capacity;
    cb->count = 0;
    cb->sz = sz;
    cb->head = cb->buffer;
    cb->tail = cb->buffer;
}

void cb_free(circular_buffer *cb)
{
    free(cb->buffer);
    // clear out other fields too, just to be safe
}

int cb_push_back(circular_buffer *cb, const void *item)
{
  void *new_head = (char *)cb->head + cb->sz;
  //printf("new_head=%d tail=%d\n", new_head, cb->tail);

  if (new_head == cb->buffer_end) {
      new_head = cb->buffer;
  }
  if (new_head == cb->tail) {
    return 1;
  }
  memcpy(cb->head, item, cb->sz);
  cb->head = new_head;
  return 0;
}

int cb_pop_front(circular_buffer *cb, void *item)
{
  void *new_tail = cb->tail + cb->sz;
  if (cb->head == cb->tail) {
    return 1;
  }
  memcpy(item, cb->tail, cb->sz);
  if (new_tail == cb->buffer_end) {
    new_tail = cb->buffer;
  }
  cb->tail = new_tail;
  return 0;
}

void *producer_thread(void *vargp)
{
    while (enabled) {
        uint8_t block[BLOCK_SIZE];
        if (cb_push_back(&cb, block) == 1) {
            printf("overflow\n");
        }
        usleep(rand() % 100);
    }
}

void *consumer_thread(void *vargp)
{
    while (enabled) {
        uint8_t block[BLOCK_SIZE];
        if (cb_pop_front(&cb, block) == 1) {
            printf("underflow\n");
        }
        usleep(rand() % 100);
    }
}


void main(void) {
    cb_init(&cb, BUFFER_SIZE, BLOCK_SIZE);

    pthread_t thread_id1, thread_id2;
    pthread_create(&thread_id1, NULL, producer_thread, NULL);
    pthread_create(&thread_id2, NULL, consumer_thread, NULL);

    while(1);

}