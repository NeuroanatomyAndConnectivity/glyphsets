function ranknormalize(filename,outname)
% normalizes binary connectivity matrices by sorting (ranking)
% reads: filename, outputs: outname

fileInfo = dir(filename);
fileSize = fileInfo.bytes;

% assuming a square matrix with float32 (4 byte)
dim = sqrt(fileSize/4);
file = fopen(filename,'r');
A = fread(file,[dim,dim],'float32');

% invalid (NotANumber) values are set to a value < -1
%this way, they are ranked lowest
A(isnan(A))=-10;

% sorting and ranking in column and in row direction
[~,IX1] = sort(A,1);
[~,IX2] = sort(A,2);
unsorted = 1:dim;

ranks1 = zeros(dim,dim);
for i=1:dim
    i
   ranks1(IX1(:,i),i)=unsorted;
end

ranks2 = zeros(dim,dim);
for i=1:dim
    i
   ranks2(i,IX2(i,:))=unsorted;
end

% for overall rank, using the maximum of the row-wise and column-wise rank
ranks = max(ranks1,ranks2);

% removes originally negative connectivity
ranks(A<0)=0;

% scaling to the range btw. 0 and 1
ranks = ranks/dim;

% writing to another square binary float32 matrix
file = fopen(outname,'w')
fwrite(file,ranks,'float32')
