
namespace PDGBoardGames
{
    public interface IBoard<TCell> where TCell : IBoardCell
    {
        int Columns { get; }
        int Rows { get; }
        IBoardColumn<TCell> this[int column] { get; }
        void Clear();
    }
}
