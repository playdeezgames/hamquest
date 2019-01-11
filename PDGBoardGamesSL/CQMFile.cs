using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Resources;
using System.Windows;
using System.Windows.Resources;

namespace PDGBoardGames
{
    public class CQMFile
    {
        byte[] buffer;
        public CQMFile(byte width, byte height)
        {
            buffer = new byte[2 + width * height];
            buffer[0] = width;
            buffer[1] = height;
        }
        public CQMFile(CQMFile copyFrom)
        {
            buffer = new byte[2 + copyFrom.Width * copyFrom.Height];
            buffer[0] = copyFrom.Width;
            buffer[1] = copyFrom.Height;
            for (byte x = 0; x < Width; ++x)
            {
                for (byte y = 0; y < Height; ++y)
                {
                    SetCellValue(x, y, copyFrom.GetCellValue(x, y));
                }
            }
        }
        public byte Width
        {
            get
            {
                return (buffer[0]);
            }
        }
        public byte Height
        {
            get
            {
                return (buffer[1]);
            }
        }
        public byte GetCellValue(byte x, byte y)
        {
            if (x < Width && y < Height)
            {
                return buffer[2 + x + y * Width];
            }
            else
            {
                return (0);
            }
        }
        public void SetCellValue(byte x, byte y, byte cellValue)
        {
            if (x < Width && y < Height)
            {
                buffer[2 + x + y * Width]=cellValue;
            }
        }
        public void Blend(CQMFile overlay,byte offsetX,byte offsetY,byte transparent)
        {
            for (byte x = 0; x < overlay.Width; ++x)
            {
                for (byte y = 0; y < overlay.Height; ++y)
                {
                    if (overlay.GetCellValue(x, y) != transparent)
                    {
                        SetCellValue((byte)(x + offsetX), (byte)(y + offsetY), overlay.GetCellValue(x, y));
                    }
                }
            }
        }
        public void ToFile(string fileName)
        {
            using (BinaryWriter writer = new BinaryWriter(new FileStream(fileName, FileMode.CreateNew)))
            {
                writer.Write(buffer);
            }
        }
    }
    public static class CQMLoader
    {
        public static CQMFile LoadFromFile(string fileName)
        {
            CQMFile result = null;
            Uri uri = new Uri(fileName,UriKind.Relative);
            StreamResourceInfo info = Application.GetResourceStream(uri);
            Stream stream = info.Stream;
            using (BinaryReader reader = new BinaryReader(stream))
            {
                byte width = reader.ReadByte();
                byte height = reader.ReadByte();
                result = new CQMFile(width, height);
                for (byte y = 0; y < result.Height; ++y)
                {
                    for (byte x = 0; x < result.Width; ++x)
                    {
                        result.SetCellValue(x, y, reader.ReadByte());
                    }
                }
            }
            return (result);
        }
    }
}
