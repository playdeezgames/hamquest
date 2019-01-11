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
using System.Windows.Media.Imaging;

namespace HamQuestSLClient
{
    public class ImageCell
    {
        private Image image;
        public bool Visible
        {
            get
            {
                return image.Visibility == Visibility.Visible;
            }
            set
            {
                if (value)
                {
                    image.Visibility = Visibility.Visible;
                }
                else
                {
                    image.Visibility = Visibility.Collapsed;
                }
            }
        }
        public string ImageSource
        {
            set
            {
                image.Source = new BitmapImage(new Uri(value, UriKind.Relative));
            }
        }
        public ImageCell(Grid theGrid, int theColumn, int theRow, string theImageSource, bool theVisible)
        {
            image = new Image();
            theGrid.Children.Add(image);
            Grid.SetColumn(image,theColumn);
            Grid.SetRow(image,theRow);
            Grid.SetColumnSpan(image, 1);
            Grid.SetRowSpan(image, 1);
            ImageSource = theImageSource;
            Visible = theVisible;
        }
    }
}
