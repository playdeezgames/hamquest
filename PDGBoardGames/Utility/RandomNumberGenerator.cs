using System;

namespace PDGBoardGames
{
    public class RandomNumberGenerator:IRandomNumberGenerator
    {
        private Random random;
        public RandomNumberGenerator(): this(null)
        {
        }
        public RandomNumberGenerator(int? seed)
        {
            if(seed.HasValue)
            {
                random = new Random(seed.Value);
            }
            else
            {
                random = new Random();
            }
        }
        public Int32 Next(Int32 maximum)
        {
            return random.Next(maximum);
        }
        public Int32 Next(Int32 minimum, Int32 maximum)
        {
            return random.Next(minimum, maximum);
        }

    }
}
