using System;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace HamQuestSLClient
{
    public class ImageCellColumn
    {
        private ImageCellStack[] imageCellStacks;
        public ImageCellColumn(Grid theGrid, int theColumn, int theRows, int theStackSize, string theImageSource, bool theVisible)
        {
            imageCellStacks = new ImageCellStack[theRows];
            for (int row = 0; row < theRows; ++row)
            {
                imageCellStacks[row] = new ImageCellStack(theGrid, theColumn, row, theStackSize, theImageSource, theVisible);
            }
        }
        public ImageCellStack this[int row]
        {
            get
            {
                if (row < 0 || row >= imageCellStacks.Length)
                {
                    return null;
                }
                else
                {
                    return imageCellStacks[row];
                }
            }
        }
        public int Rows
        {
            get
            {
                return imageCellStacks.Length;
            }
        }
        public int Layers
        {
            get
            {
                return imageCellStacks[0].Layers;
            }
        }
    }
}
