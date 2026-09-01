def main() -> None:
    import torch

    print(f"torch {torch.__version__}, cuda available: {torch.cuda.is_available()}")


if __name__ == "__main__":
    main()
