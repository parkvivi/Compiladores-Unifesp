LEX      = flex
BISON    = bison
CC       = gcc
CFLAGS   = -Wall -Wextra

LEX_SRC   = src/lexico/lexico.l
BISON_SRC = src/sintatico/sintatico.y
BUILD_DIR = build

ifeq ($(OS),Windows_NT)
    MKDIR = if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
    RM = if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)

    BISON = C:\FLEXWI~1\bison\bin\bison.exe

    LEX_OUTPUT   = $(BUILD_DIR)\lex.yy.c
    BISON_OUTPUT = $(BUILD_DIR)\sintatico.tab.c
    BISON_HEADER = $(BUILD_DIR)\sintatico.tab.h

    MOVE_LEX   = move /Y lex.yy.c $(LEX_OUTPUT)
    MOVE_BISON = move /Y sintatico.tab.c $(BISON_OUTPUT)
    MOVE_HDR   = move /Y sintatico.tab.h $(BISON_HEADER)

    PARSER_BIN = $(BUILD_DIR)\parser.exe
    SCANNER    = $(BUILD_DIR)\scanner.exe
else
    MKDIR = mkdir -p $(BUILD_DIR)
    RM = rm -rf $(BUILD_DIR)

    LEX_OUTPUT   = $(BUILD_DIR)/lex.yy.c
    BISON_OUTPUT = $(BUILD_DIR)/sintatico.tab.c
    BISON_HEADER = $(BUILD_DIR)/sintatico.tab.h

    MOVE_LEX   = mv lex.yy.c $(LEX_OUTPUT)
    MOVE_BISON = mv sintatico.tab.c $(BISON_OUTPUT)
    MOVE_HDR   = mv sintatico.tab.h $(BISON_HEADER)

    PARSER_BIN = $(BUILD_DIR)/parser
    SCANNER    = $(BUILD_DIR)/scanner
endif

all: $(PARSER_BIN)

parser: $(PARSER_BIN)

scanner: CFLAGS += -DLEX_STANDALONE
scanner: $(SCANNER)

$(PARSER_BIN): $(LEX_OUTPUT) $(BISON_OUTPUT)
	$(CC) $(CFLAGS) -o $@ $(LEX_OUTPUT) $(BISON_OUTPUT)

$(SCANNER): $(LEX_OUTPUT)
	$(CC) $(CFLAGS) -o $@ $(LEX_OUTPUT)

$(LEX_OUTPUT): $(LEX_SRC) $(BISON_HEADER)
	$(MKDIR)
	$(LEX) -o$(LEX_OUTPUT) $<

$(BISON_OUTPUT) $(BISON_HEADER): $(BISON_SRC)
	$(MKDIR)
	$(BISON) -d -o $(BISON_OUTPUT) --defines=$(BISON_HEADER) $(BISON_SRC)

clean:
	$(RM)

.PHONY: all clean parser scanner
