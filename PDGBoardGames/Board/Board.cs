
using System.Collections.Generic;
namespace PDGBoardGames
{
    public class Board<TCell>:IBoard<TCell> where TCell : IBoardCell, new()
    {
        private IList<IBoardColumn<TCell>> _columns;
        public int Columns
        {
            get
            {
                return (_columns.Count);
            }
        }
        public int Rows
        {
            get
            {
                return (_columns[0].Rows);
            }
        }
        public IBoardColumn<TCell> this[int column]
        {
            get
            {
                return (_columns[column]);
            }
        }
        private Board()
        {
        }
        public Board(int columns, int rows)
        {
            _columns = new List<IBoardColumn<TCell>>();
            for (int column = 0; column < columns; ++column)
            {
                _columns.Add(new BoardColumn<TCell>(rows));
            }
        }
        public virtual void Clear()
        {
            foreach (IBoardColumn<TCell> column in _columns)
            {
                column.Clear();
            }
        }
    }
}
