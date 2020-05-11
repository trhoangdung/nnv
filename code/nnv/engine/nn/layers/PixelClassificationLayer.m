classdef PixelClassificationLayer < handle
    % Pixel Classification Layer object to verify segmentation networks
    % Author: Dung Tran
    % Date: 4/12/2020
    
    properties
        Name = 'PixelClassificationLayer';
        Classes = [];
        OutputSize = [];
        
        NumInputs = 1;
        InputNames = {'in'};
        
    end
    
    methods
        
        function obj = PixelClassificationLayer(varargin)
            % @name: name of the layer
            % @classes: array of class
            % @outputSize: outputSize
            
            % author: Dung Tran
            % date:4/12/2020
            
            switch nargin
                
                case 3
                    
                    name = varargin{1};
                    classes = varargin{2};
                    outputSize = varargin{3};
                    
                    if ~ischar(name)
                        error('Invalid name, should be a charracter array');
                    end

                    if ~ismatrix(classes)
                        error('Invalid classes, should be a matrix');
                    end

                    if ~ismatrix(outputSize)
                        error('Invalid outputSize');
                    end           

                    if length(outputSize) ~= 3
                        error('Invalid outputSize matrix');
                    end

                    if length(classes) ~= outputSize(1, 3)
                        error('Inconsistency betwen the number of classes and the outputSize');
                    end

                    obj.Name = name;
                    obj.OutputSize = outputSize;
                    
                case 5 % used to parse the Matlab pixelClassificationLayer
                    
                    obj.Name = varargin{1};
                    classes = varargin{2};
                    obj.OutputSize = varargin{3};
                    obj.NumInputs = varargin{4};
                    obj.InputNames = varargin{5};
                    
                otherwise
                    error('Invalid number of input arguments');
            end
            
            A = categories(classes);
            B = [A; {'unknown'}; {'misclass'}]; % add two more classes for analysis
            obj.Classes = categorical(B);
            
            
            
        end
            
    end
        
        
    methods
        
        %  get an array of classes
        function classes = getClasses(obj, idxs)
            % @idxs: index array
            % author: Dung Tran
            % date: 4/22/2020
            
            n = length(idxs);
            classes = [];
            for i=1:n
                if idxs(i) > length(obj.Classes)
                    error("Invalid class index %d (input class index) > %d (maximum class index)", idxs(i), length(obj.Classes));
                end
                classes = [classes string(obj.Classes(idxs(i)))];
            end
           
        end
        
        % classified label for all pixels of an image
        function varargout = evaluate(obj,image)
            %@image: an output image before softmax layer with the size of
            %        m1 x m2 x n, where n is the number of labels needs to
            %        be classified
            % @seg_im_cat: segmentation image with class categories
            % @seg_im_id: segmentation image with class index
            
            % author: Dung Tran
            % date: 4/12/2020
            % update: 4/22/2020
                     
            n = size(image);
            if length(n)~= 3
                error('Output image should be a 3-dimensional image');
            end
            [~, y] = max(image, [], 3); 
            S = cell(n(1),n(2));
            classes = categories(obj.Classes);
            X = zeros(n(1), n(2));
            for i=1:n(1)
                for j=1:n(2)
                    S{i,j} =  classes{y(i,j)};
                    X(i,j) = y(i,j);
                end
            end
            seg_im_cat = categorical(S);
            seg_im_id = X;
            
            switch nargout
                case 2
                    varargout{1} = seg_im_id;
                    varargout{2} = seg_im_cat;
                case 1
                    varargout{1} = seg_im_id;
                otherwise
                    error("Invalid number output argument, should be 1 or 2");
            end

        end
        
        % reachability with imagestar
        function [seg_im_id, seg_im_cat, mis_px_id] = reach_star_single_input(obj, IS, ~)
            % @IS: imageStar input set
            % @seg_im_id: segmentation image with class index
            % @seg_im_cat: segmentation image with class name (a
            % categorical object)
            % @mis_px_id: example of misclassified pixel class index
            
            % author: Dung Tran
            % date: 4/12/2020
            % upate: 4/22/2020
            
            [im_lb, im_ub] = IS.estimateRanges;
            [~,y1] = max(im_lb, [], 3);
            [~,y2] = max(im_ub, [], 3);
            classes = categories(obj.Classes);
            
            n = size(y1);
            
            S = cell(n(1),n(2));
            X = zeros(n(1),n(2));
            Y = cell(n(1), n(2));
            for i=1:n(1)
                for j=1:n(2)
                    if y1(i,j) == y2(i,j)
                        S{i, j} = classes{y1(i,j)};
                        X(i,j) = y1(i,j);
                    else
                        S{i,j} = 'unknown';
                        X(i, j) = length(classes)-1; % unknown label index
                        Y{i, j} = [y1(i,j) y2(i,j)]; % example of misclassified label
                    end
                end
            end
            
            seg_im_cat = categorical(S);
            seg_im_id = X;
            mis_px_id = Y;
        end
        
        
        % reachability with imagestar
        function [seg_ims_ids, seg_ims_cats, mis_pix_ids] = reach_star_multipleInputs(obj, in_images, option)
            % @in_images: an array of imageStar input set
            % @seg_im_id: segmentation image with class index
            % @seg_im_cat: segmentation image with class name (a
            % categorical object)
            % @mis_px_id: example of misclassified pixel class index
            
            % author: Dung Tran
            % date: 4/12/2020
            % upate: 4/22/2020
            
            
            n = length(in_images);
            seg_ims_ids = cell(n, 1);
            seg_ims_cats = cell(n,1);
            mis_pix_ids = cell(n,1);
            if strcmp(option, 'parallel')
                parfor i=1:n
                    [seg_ims_ids{i}, seg_ims_cats{i}, mis_pix_ids{i}] = obj.reach_star_single_input(in_images(i));
                end
            elseif strcmp(option, 'single') || isempty(option)
                for i=1:n
                    [seg_ims_ids{i}, seg_ims_cats{i}, mis_pix_ids{i}] = obj.reach_star_single_input(in_images(i));
                end
            else
                error('Unknown computation option');

            end           
            
            
        end
        
        
        % main reach method
        function [seg_ims_ids, seg_ims_cats, mis_pix_ids] = reach(varargin)
            % @in_images: an array of imageStar input set
            % @seg_im_id: segmentation image with class index
            % @seg_im_cat: segmentation image with class name (a
            % categorical object)
            % @mis_px_id: example of misclassified pixel class index
            
            % author: Dung Tran
            % date: 4/22/2020
            % upate: 
            
           switch nargin
                case 4
                    obj = varargin{1};
                    in_images = varargin{2};
                    method = varargin{3};
                    option = varargin{4};
                case 3
                    obj = varargin{1};
                    in_images = varargin{2}; 
                    method = varargin{3};
                    option = 'single';
                case 2
                    obj = varargin{1};
                    in_images = varargin{2}; 
                    method = 'approx-star';
                    option = 'single';
                    
                otherwise
                    error('Invalid number of input arguments, should be 1, 2 or 3');
            end
         
            if strcmp(method, 'approx-star') || strcmp(method, 'exact-star') || strcmp(method, 'abs-dom')
                [seg_ims_ids, seg_ims_cats, mis_pix_ids] = obj.reach_star_multipleInputs(in_images, option);
            elseif strcmp(method, 'approx-zono') 
                error('NNV have not support approx-zono method yet');
            else
                error('Unknown reachability method');
            end
            
            
            
        end
     
        
    end
    
    
    methods(Static)
        % parsing method
        
        function L = parse(pixel_classification_layer)
            % @pixel_classification_layer: 
            % @L: constructed layer
                        
            % author: Dung Tran
            % date: 4/12/2020
            
            
            if ~isa(pixel_classification_layer, 'nnet.cnn.layer.PixelClassificationLayer')
                error('Input is not a Matlab nnet.cnn.layer.PixelClassificationLayer');
            end
            
            L = PixelClassificationLayer(pixel_classification_layer.Name, pixel_classification_layer.Classes, pixel_classification_layer.OutputSize, pixel_classification_layer.NumInputs, pixel_classification_layer.InputNames);
            
            fprintf('\nParsing a Matlab pixel classification layer is done successfully');
            
        end
        
        
    end
end
