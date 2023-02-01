EXE=$(TEST_NAME).exe
DEPS=../Args.hpp

src=$(EXE:.exe=.cpp)

# BUILD_CMD_$(TOOLSET):
#
#!!Alas, can't do this in NMAKE... :-/
#
#BUILD_CMD_msvc=build-vc.cmd
#BUILD_CMD_gcc=build-gcc.sh
#BUILD_CMD=$(BUILD_CMD_$(TOOLSET)) # Syntax error!
#!!Or this:
#BUILD_CMD_=BUILD_CMD_$(TOOLSET)
#BUILD_CMD=$($(BUILD_CMD_))       # Syntax error!
#!
#! So, sadly, our only choice is to delegate the dispatching
#! to a common/generic build script from here! :-o
#! And to keep being uniform, it needs to be .sh, bridged e.g.
#! by BusyBox on Windows.
#!
GENERIC_BUILD_CMD=@busybox sh $(TEST_ENGINE_DIR)/build.sh
$(EXE): $(DEPS) $(src)
	$(GENERIC_BUILD_CMD) $@ $?
