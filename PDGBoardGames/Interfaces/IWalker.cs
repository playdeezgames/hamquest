
using System.Collections.Generic;
namespace PDGBoardGames
{
    public interface IWalker<TDirection>
    {
        int Count { get;}
        IEnumerable<TDirection> Values { get; }
        TDirection Opposite(TDirection direction);
        int GetNextColumn(int startColumn, int startRow, TDirection direction);
        int GetNextRow(int startColumn, int startRow, TDirection direction);
    }
}
