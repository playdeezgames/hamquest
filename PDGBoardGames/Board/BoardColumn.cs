
namespace PDGBoardGames
{
    public class BoardColumn<TCell>:IBoardColumn<TCell> where TCell : IBoardCell, new()
    {
        private TCell[] _cells;
        public int Rows
        {
            get
            {
                return (_cells.Length);
            }
        }
        public TCell this[int row]
        {
            get
            {
                return (_cells[row]);
            }
            set
            {
                _cells[row] = value;
            }
        }
        private BoardColumn()
        {
        }
        public BoardColumn(int rows)
        {
            _cells = new TCell[rows];
            for (int row = 0; row < _cells.Length; ++row)
            {
                this[row] = new TCell();
            }
            this.Clear();
        }
        public void Clear()
        {
            foreach (TCell cell in _cells)
            {
                cell.Clear();
            }
        }
    }
}
