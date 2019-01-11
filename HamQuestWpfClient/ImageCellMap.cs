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
    public class ImageCellMap
    {
        private ImageCellColumn[] imageCellColumns;
        public ImageCellMap(Grid theGrid, int theColumns, int theRows, int theStackSize, string theImageSource, bool theVisible)
        {
            imageCellColumns = new ImageCellColumn[theColumns];
            for (int column = 0; column < theColumns; ++column)
            {
                imageCellColumns[column] = new ImageCellColumn(theGrid, column, theRows, theStackSize, theImageSource, theVisible);
            }
        }
        public ImageCellColumn this[int column]
        {
            get
            {
                if (column < 0 || column >= imageCellColumns.Length)
                {
                    return null;
                }
                else
                {
                    return imageCellColumns[column];
                }
            }
        }
        public int Columns
        {
            get
            {
                return imageCellColumns.Length;
            }
        }
        public int Rows
        {
            get
            {
                return imageCellColumns[0].Rows;
            }
        }
        public int Layers
        {
            get
            {
                return imageCellColumns[0].Layers;
            }
        }
    }
}
