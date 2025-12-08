LEX = flex
CC = gcc
CFLAGS = -Wall -Wextra

LEX_SRC = src/lexico/lexico.l
BUILD_DIR = build

ifeq ($(OS),Windows_NT)
    MKDIR = if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
    RM = if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
    SCANNER = $(BUILD_DIR)\scanner.exe
    LEX_OUTPUT = $(BUILD_DIR)\lex.yy.c
    MOVE = move /Y lex.yy.c $(LEX_OUTPUT)
else
    MKDIR = mkdir -p $(BUILD_DIR)
    RM = rm -rf $(BUILD_DIR)
    SCANNER = $(BUILD_DIR)/scanner
    LEX_OUTPUT = $(BUILD_DIR)/lex.yy.c
    MOVE = mv lex.yy.c $(LEX_OUTPUT)
endif

all: $(SCANNER)

$(SCANNER): $(LEX_OUTPUT)
	$(CC) $(CFLAGS) -o $@ $<

$(LEX_OUTPUT): $(LEX_SRC)
	$(MKDIR)
	$(LEX) $<
	$(MOVE)

clean:
	$(RM)

.PHONY: all clean
