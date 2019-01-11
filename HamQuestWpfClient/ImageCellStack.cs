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
    public class ImageCellStack
    {
        private ImageCell[] imageCells;
        public ImageCellStack(Grid theGrid, int theColumn, int theRow,int theStackSize, string theImageSource, bool theVisible)
        {
            imageCells = new ImageCell[theStackSize];
            for (int index = 0; index < imageCells.Length; ++index)
            {
                imageCells[index] = new ImageCell(theGrid, theColumn, theRow, theImageSource, theVisible);
            }
        }
        public ImageCell this[int index]
        {
            get
            {
                if (index < 0 || index >= imageCells.Length)
                {
                    return null;
                }
                else
                {
                    return imageCells[index];
                }
            }
        }
        public int Layers
        {
            get
            {
                return imageCells.Length;
            }
        }
    }
}
