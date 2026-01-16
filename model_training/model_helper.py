import pandas as pd
import os
def get_df(path):

    # SET YOUR PATH
    # Replace this with the actual path to your "A_DeviceMotion_data" folder
    dataset_path = path 

    # . DEFINE THE COLUMNS & LABELS
    # The folder names start with these codes. We map them to readable names.
    activity_map = {
        'dws': 'Downstairs',
        'ups': 'Upstairs',
        'sit': 'Sitting',
        'std': 'Standing',
        'wlk': 'Walking',
        'jog': 'Jogging'
    }

    data_frames = []

    # LOOP THROUGH ALL FOLDERS
    for folder in os.listdir(dataset_path):
        # Only process legitimate folders (skip hidden system files)
        if not folder.startswith('.'): 
            
            # Extract Activity Label (e.g., 'dws_1' -> 'dws')
            activity_code = folder.split('_')[0]
            activity_label = activity_map.get(activity_code, 'Unknown')
            
            folder_full_path = os.path.join(dataset_path, folder)
            
            #  LOOP THROUGH ALL CSV FILES IN THAT FOLDER
            if os.path.isdir(folder_full_path):
                for filename in os.listdir(folder_full_path):
                    if filename.endswith('.csv'):
                        
                        # Read the CSV
                        file_path = os.path.join(folder_full_path, filename)
                        df_temp = pd.read_csv(file_path)
                        
                        # Add meaningful columns
                        df_temp['activity'] = activity_label
                        df_temp['subject_id'] = filename.split('_')[1].split('.')[0] # 'sub_1.csv' -> '1'
                        
                        # Rename the confusing 'Unnamed: 0' column to 'time_step'
                        df_temp.rename(columns={'Unnamed: 0': 'time_step'}, inplace=True)
                        
                        data_frames.append(df_temp)

    #  CONCATENATE INTO ONE MASTER DATAFRAME
    final_df = pd.concat(data_frames, ignore_index=True)
    return final_df

    