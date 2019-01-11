using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace PDGBoardGames
{
    public class Board<CellType> where CellType : BoardCellBase, new()
    {
        private BoardColumn<CellType>[] columns;
        public int Columns
        {
            get
            {
                return (columns.Length);
            }
        }
        public int Rows
        {
            get
            {
                return (columns[0].Rows);
            }
        }
        public BoardColumn<CellType> this[int column]
        {
            get
            {
                return (columns[column]);
            }
        }
        private Board()
        {
        }
        public Board(int theColumns, int theRows)
        {
            columns = new BoardColumn<CellType>[theRows];
            for (int column = 0; column < theColumns; ++column)
            {
                columns[column] = new BoardColumn<CellType>(column, theRows);
            }
            Clear();
        }
        public virtual void Clear()
        {
            foreach (BoardColumn<CellType> column in columns)
            {
                column.Clear();
            }
        }
    }
}
