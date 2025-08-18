# From: C:\Users\akash\Documents\GitHub\backdoor420\hybrid_malware_platform
.\venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
pip install python-magic-bin==0.4.14 requests

# Test-run the app once (optional, see any errors directly)
python backend\app.py

# Now run the self-check (from either folder)
# If selfCheck.py is in backdoor420:
cd ..        # to backdoor420
python .\selfCheck.py

# Or, if selfCheck.py is inside hybrid_malware_platform:
cd .\hybrid_malware_platform
python .\selfCheck.py
