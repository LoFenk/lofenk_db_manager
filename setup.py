from setuptools import setup, find_packages

setup(
    name="lofenk-db-manager",
    version="0.1",
    packages=find_packages(),
    scripts=['myscript/lofenk-db-manager.sh'],
    install_requires=[
        'boto3>=1.26',
        'botocore>=1.29',
    ],
)
