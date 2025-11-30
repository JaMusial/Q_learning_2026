#!/bin/bash
# ========================================================================
# LaTeX Compilation Script
# ========================================================================
# Compiles the Q2d manuscript with proper BibTeX handling
# Usage: ./compile.sh [clean|full|quick]
# ========================================================================

MAIN_FILE="00_main"
FIGURES_DIR="figures"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ========================================================================
# Function: Clean build artifacts
# ========================================================================
clean_build() {
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    rm -f *.aux *.log *.bbl *.blg *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz
    rm -f ${MAIN_FILE}.pdf
    echo -e "${GREEN}Clean complete.${NC}"
}

# ========================================================================
# Function: Check for figures directory
# ========================================================================
check_figures() {
    if [ ! -d "$FIGURES_DIR" ]; then
        echo -e "${YELLOW}Warning: figures/ directory does not exist${NC}"
        echo -e "${YELLOW}Creating figures/ directory...${NC}"
        mkdir -p "$FIGURES_DIR"
        echo -e "${YELLOW}Place your .pdf figure files in this directory${NC}"
    else
        echo -e "${GREEN}figures/ directory found${NC}"
        # Count PDF files in figures directory
        pdf_count=$(find "$FIGURES_DIR" -name "*.pdf" | wc -l)
        echo -e "${GREEN}Found $pdf_count PDF figure(s)${NC}"
    fi
}

# ========================================================================
# Function: Full compilation with BibTeX
# ========================================================================
full_compile() {
    echo -e "${GREEN}Starting full compilation...${NC}"

    # First pass
    echo -e "${YELLOW}Pass 1/4: Initial pdflatex compilation...${NC}"
    pdflatex -interaction=nonstopmode ${MAIN_FILE}.tex
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error in first pdflatex pass${NC}"
        return 1
    fi

    # BibTeX
    echo -e "${YELLOW}Pass 2/4: BibTeX for references...${NC}"
    bibtex ${MAIN_FILE}
    if [ $? -ne 0 ]; then
        echo -e "${RED}Warning: BibTeX errors (may be normal if no citations yet)${NC}"
    fi

    # Second pass
    echo -e "${YELLOW}Pass 3/4: Second pdflatex compilation...${NC}"
    pdflatex -interaction=nonstopmode ${MAIN_FILE}.tex
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error in second pdflatex pass${NC}"
        return 1
    fi

    # Third pass
    echo -e "${YELLOW}Pass 4/4: Final pdflatex compilation...${NC}"
    pdflatex -interaction=nonstopmode ${MAIN_FILE}.tex
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error in final pdflatex pass${NC}"
        return 1
    fi

    echo -e "${GREEN}Compilation successful!${NC}"
    echo -e "${GREEN}Output: ${MAIN_FILE}.pdf${NC}"
}

# ========================================================================
# Function: Quick compilation (no BibTeX)
# ========================================================================
quick_compile() {
    echo -e "${GREEN}Starting quick compilation (no BibTeX)...${NC}"
    pdflatex -interaction=nonstopmode ${MAIN_FILE}.tex
    if [ $? -ne 0 ]; then
        echo -e "${RED}Compilation error${NC}"
        return 1
    fi
    echo -e "${GREEN}Quick compilation successful!${NC}"
    echo -e "${GREEN}Output: ${MAIN_FILE}.pdf${NC}"
}

# ========================================================================
# Main Script
# ========================================================================

# Check for pdflatex
if ! command -v pdflatex &> /dev/null; then
    echo -e "${RED}Error: pdflatex not found${NC}"
    echo "Please install a LaTeX distribution (TeX Live, MiKTeX, etc.)"
    exit 1
fi

# Parse command line argument
case "${1}" in
    clean)
        clean_build
        ;;
    full)
        check_figures
        full_compile
        ;;
    quick)
        check_figures
        quick_compile
        ;;
    *)
        echo "Usage: $0 [clean|full|quick]"
        echo ""
        echo "Options:"
        echo "  clean  - Remove all build artifacts"
        echo "  full   - Full compilation with BibTeX (4 passes)"
        echo "  quick  - Single pdflatex pass (for draft checking)"
        echo ""
        echo "Running full compilation by default..."
        check_figures
        full_compile
        ;;
esac

# Check if PDF was created
if [ -f "${MAIN_FILE}.pdf" ]; then
    pdf_size=$(du -h "${MAIN_FILE}.pdf" | cut -f1)
    echo -e "${GREEN}PDF file size: $pdf_size${NC}"

    # Count pages (if pdfinfo available)
    if command -v pdfinfo &> /dev/null; then
        page_count=$(pdfinfo "${MAIN_FILE}.pdf" | grep "Pages:" | awk '{print $2}')
        echo -e "${GREEN}Page count: $page_count${NC}"
    fi
fi

echo -e "${GREEN}Done.${NC}"
