
namespace PDGBoardGames
{
    public interface IBoardColumn<TCell> where TCell : IBoardCell
    {
        int Rows { get; }
        TCell this[int row] { get; set; }
        void Clear();
    }
}
