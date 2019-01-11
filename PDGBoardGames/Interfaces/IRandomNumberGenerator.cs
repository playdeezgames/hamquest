using System;

namespace PDGBoardGames
{
    public interface IRandomNumberGenerator
    {
        Int32 Next(Int32 maximum);
        Int32 Next(Int32 minimum, Int32 maximum);
    }
}
