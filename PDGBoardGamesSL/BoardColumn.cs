using System;
using System.Collections.Generic;
using System.Text;

namespace PDGBoardGames
{
    public class BoardColumn<CellType> where CellType : BoardCellBase, new()
    {
        private int column;
        private CellType[] cells;
        public int Rows
        {
            get
            {
                return (cells.Length);
            }
        }
        public CellType this[int row]
        {
            get
            {
                return (cells[row]);
            }
            set
            {
                cells[row] = value;
                if (cells[row]!=null)
                {
                    cells[row].Column = column;
                    cells[row].Row = row;
                }
            }
        }
        private BoardColumn()
        {
        }
        public BoardColumn(int theColumn,int theRows)
        {
            column = theColumn;
            cells = new CellType[theRows];
            for (int row = 0; row < cells.Length; ++row)
            {
                this[row] = new CellType();
            }
            this.Clear();
        }
        public void Clear()
        {
            foreach (CellType cell in cells)
            {
                cell.Clear();
            }
        }
    }
}
