# ============================================================
# 3dre - Modern OpenGL Engine
# ============================================================
ASM      := nasm
CC       := gcc

SRC_DIR  := src
INC_DIR  := include
BLD_DIR  := build
OBJ_DIR  := $(BLD_DIR)/obj

TARGET   := $(BLD_DIR)/engine.exe

ASMFLAGS := -f win64 -g -F cv8 -I $(INC_DIR)/
LDFLAGS  := -m64 -mwindows
LIBS     := -lopengl32 -lgdi32 -luser32 -lkernel32 -lole32 -lgdiplus -lwinmm
SOURCES  := $(shell find $(SRC_DIR) -name '*.asm')
OBJECTS  := $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.o,$(SOURCES))

.PHONY: all clean run rebuild

all: $(TARGET)

$(TARGET): $(OBJECTS)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)
	@mkdir -p $(BLD_DIR)/shaders
	@cp -u shaders/* $(BLD_DIR)/shaders/ 2>/dev/null || true
	@mkdir -p $(BLD_DIR)/assets
	@cp -ru assets/* $(BLD_DIR)/assets/ 2>/dev/null || true
	@echo "=== Built: $@ ==="
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) -o $@ $<

run: all
	./$(TARGET)

clean:
	rm -rf $(BLD_DIR)

rebuild: clean all